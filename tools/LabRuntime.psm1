#requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Field {
    param($Object, [string]$Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
    } elseif ($null -ne $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    return $Default
}

function Invoke-CheckedAz {
    param($Context, [string[]]$Arguments, [switch]$TextOutput)
    # Tests inject an invoker returning { ExitCode, Output }; production always checks the native exit code.
    if ($null -ne $Context.Invoker) {
        $result = & $Context.Invoker $Arguments
        $exitCode = $result.ExitCode
        $raw = [string]$result.Output
    } else {
        if (-not (Get-Command az -ErrorAction SilentlyContinue)) { throw 'Azure CLI is missing. Install it yourself using the official instructions in Lab 00.' }
        $priorExtension = $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL
        $priorBicepCheck = $env:AZURE_BICEP_CHECK_VERSION
        try {
            $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL = 'no'
            $env:AZURE_BICEP_CHECK_VERSION = 'false'
            $outputArgs = if ($TextOutput) { @('--only-show-errors') } else { @('--only-show-errors', '--output', 'json') }
            $raw = (& az @Arguments @outputArgs 2>&1 | Out-String).Trim()
            $exitCode = $LASTEXITCODE
        } finally {
            $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL = $priorExtension
            $env:AZURE_BICEP_CHECK_VERSION = $priorBicepCheck
        }
    }
    if ($exitCode -ne 0) {
        # Do not persist Azure's error body: it can include tenant IDs or learner details.
        $safeCommand = ($Arguments | Select-Object -First 3) -join ' '
        throw "Azure CLI failed (exit $exitCode): az $safeCommand. Rerun that read-only command yourself to inspect its error. No success is assumed."
    }
    if ($TextOutput) { return $raw }
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    try { return ,($raw | ConvertFrom-Json -Depth 50 -NoEnumerate) }
    catch { throw 'Azure CLI returned invalid JSON; stopped without assuming success.' }
}

function Save-Evidence {
    param($Context, [string]$Name, $Result)
    $directory = Join-Path $Context.Root "evidence/$($Context.LabId)/$($Context.RunId)"
    $null = New-Item -ItemType Directory -Force -Path $directory
    $Result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $directory "$Name.json") -Encoding utf8
}

function Assert-Ownership {
    param($Context, $Resource, [string]$Label)
    $tags = Get-Field $Resource 'tags'
    foreach ($key in $Context.Tags.Keys) {
        if ((Get-Field $tags $key '') -cne $Context.Tags[$key]) { throw "Ownership refusal: $Label does not have the exact project, lab, and run tags. No changes made to it." }
    }
}

function Assert-Readiness {
    param($Context, [switch]$Deployment)
    if ($PSVersionTable.PSVersion -lt [version]'7.4') { throw 'PowerShell 7.4 or newer is required.' }
    # This one context command deliberately omits --subscription: it verifies the active caller context.
    $account = Invoke-CheckedAz $Context @('account', 'show')
    if ((Get-Field $account 'environmentName' '') -cne 'AzureCloud') { throw 'Unsupported cloud context. These live scripts require the public AzureCloud environment; sovereign clouds are conceptual exercises only.' }
    if ((Get-Field $account 'id' '') -ine $Context.SubscriptionId) { throw 'Subscription mismatch. Select the intended subscription explicitly with az account set before retrying.' }
    if ((Get-Field $account 'state' '') -ine 'Enabled') { throw 'The selected subscription is not enabled.' }
    $locations = Invoke-CheckedAz $Context @('account', 'list-locations', '--subscription', $Context.SubscriptionId)
    if ($Context.Location -notin @($locations | ForEach-Object { Get-Field $_ 'name' '' })) { throw 'Unknown region. Use a canonical region name from az account list-locations.' }
    if ($Deployment) {
        $providers = @()
        if ($Context.Network) { $providers += 'Microsoft.Network' }
        if ($Context.Storage) { $providers += 'Microsoft.Storage' }
        foreach ($namespace in $providers) {
            $provider = Invoke-CheckedAz $Context @('provider', 'show', '--namespace', $namespace, '--subscription', $Context.SubscriptionId)
            if ((Get-Field $provider 'registrationState' '') -ine 'Registered') { throw "$namespace is not registered. Ask your subscription administrator; this tool never registers providers." }
        }
        if ($Context.Profile -eq 'bicep') {
            $version = Invoke-CheckedAz $Context @('bicep', 'version') -TextOutput
            if ($version -notmatch 'Bicep CLI version') { throw 'An existing Azure CLI Bicep installation is required. Install it explicitly using the Lab 00 instructions.' }
        }
    }
}

function Test-GroupExists {
    param($Context)
    $exists = Invoke-CheckedAz $Context @('group', 'exists', '--name', $Context.Group, '--subscription', $Context.SubscriptionId)
    if ($exists -isnot [bool]) { throw 'Unexpected group existence response; refusing to continue.' }
    return $exists
}

function Get-OwnedGroup {
    param($Context)
    $group = Invoke-CheckedAz $Context @('group', 'show', '--name', $Context.Group, '--subscription', $Context.SubscriptionId)
    Assert-Ownership $Context $group $Context.Group
    if ((Get-Field $group 'location' '') -ine $Context.Location) { throw 'Existing resource group region differs from -Location. No changes made.' }
    return $group
}

function Assert-NetworkState {
    param($Context)
    $network = Invoke-CheckedAz $Context @('network', 'vnet', 'show', '--resource-group', $Context.Group, '--name', 'vnet-az900', '--subscription', $Context.SubscriptionId)
    Assert-Ownership $Context $network 'vnet-az900'
    if ((Get-Field $network 'location' '') -ine $Context.Location) { throw 'Virtual network region differs from the requested region.' }
    $prefixes = @(Get-Field (Get-Field $network 'addressSpace') 'addressPrefixes' @())
    $subnets = @(Get-Field $network 'subnets' @())
    $peerings = @(Get-Field $network 'virtualNetworkPeerings' @())
    if ($prefixes.Count -ne 1 -or $prefixes[0] -ne '10.90.0.0/16' -or $subnets.Count -ne 1 -or $peerings.Count -ne 0) { throw 'Unexpected virtual network prefixes, subnets, or peerings. Inspect and remove unrelated additions yourself.' }
    $subnet = $subnets[0]
    if ((Get-Field $subnet 'name' '') -cne 'subnet-default' -or (Get-Field $subnet 'addressPrefix' '') -ne '10.90.1.0/24') { throw 'Unexpected subnet name or address prefix.' }
    foreach ($property in @('ipConfigurations', 'privateEndpoints', 'delegations', 'serviceEndpoints', 'serviceAssociationLinks', 'resourceNavigationLinks')) {
        if (@(Get-Field $subnet $property @()).Count -gt 0) { throw "Unexpected subnet children: $property. Refusing reuse or deletion." }
    }
    foreach ($property in @('networkSecurityGroup', 'routeTable', 'natGateway')) {
        if ($null -ne (Get-Field $subnet $property)) { throw "Unexpected subnet association: $property. Refusing reuse or deletion." }
    }
}

function Assert-StorageChildren {
    param($Context, [switch]$RequireContainer)
    $containers = Invoke-CheckedAz $Context @('storage', 'container-rm', 'list', '--resource-group', $Context.Group, '--storage-account', $Context.Account, '--subscription', $Context.SubscriptionId)
    foreach ($container in @($containers)) {
        if ((Get-Field $container 'name' '') -cne 'practice') { throw 'Unexpected blob container; refusing reuse or deletion of this storage account.' }
        $metadata = Get-Field $container 'metadata'
        foreach ($key in @('project', 'lab', 'run')) {
            $expected = switch ($key) { 'project' { 'az900-azure-fundamentals-labs' }; 'lab' { $Context.LabId }; 'run' { $Context.RunId } }
            if ((Get-Field $metadata "az900_$key" '') -cne $expected) { throw 'Practice container ownership metadata does not match; refusing reuse or deletion.' }
        }
        if ((Get-Field $container 'publicAccess' 'None') -notin @('None', 'none', $null, '')) { throw 'Practice container has public access enabled.' }
    }
    if ($RequireContainer -and @($containers).Count -ne 1) { throw 'Expected one private practice container.' }
    # Inspect other storage children using control-plane APIs; no account keys or data-plane privileges are requested.
    $shares = Invoke-CheckedAz $Context @('storage', 'share-rm', 'list', '--resource-group', $Context.Group, '--storage-account', $Context.Account, '--subscription', $Context.SubscriptionId)
    if (@($shares).Count -gt 0) { throw 'Unexpected file shares; refusing reuse or deletion.' }
    foreach ($service in @('queue', 'table')) {
        $url = "https://management.azure.com/subscriptions/$($Context.SubscriptionId)/resourceGroups/$($Context.Group)/providers/Microsoft.Storage/storageAccounts/$($Context.Account)/${service}Services/default/${service}s?api-version=2023-05-01"
        $children = Invoke-CheckedAz $Context @('rest', '--method', 'get', '--url', $url, '--subscription', $Context.SubscriptionId)
        $collection = if ($null -ne $children) { $children.PSObject.Properties['value'] } else { $null }
        if ($null -eq $collection -or $collection.Value -isnot [array]) { throw "Unrecognized $service inventory response; refusing reuse or deletion." }
        if ($collection.Value.Count -gt 0 -or -not [string]::IsNullOrEmpty((Get-Field $children 'nextLink' ''))) { throw "Unexpected $service children or pagination; refusing reuse or deletion." }
    }
    return @($containers).Count
}

function Assert-StorageState {
    param($Context, [switch]$RequireContainer)
    $account = Invoke-CheckedAz $Context @('storage', 'account', 'show', '--resource-group', $Context.Group, '--name', $Context.Account, '--subscription', $Context.SubscriptionId)
    Assert-Ownership $Context $account $Context.Account
    if ((Get-Field $account 'location' '') -ine $Context.Location -or (Get-Field $account 'kind' '') -cne 'StorageV2' -or (Get-Field (Get-Field $account 'sku') 'name' '') -cne 'Standard_LRS') { throw 'Storage account region, kind, or SKU differs from the lab specification.' }
    if ((Get-Field $account 'enableHttpsTrafficOnly') -ne $true -or (Get-Field $account 'allowBlobPublicAccess') -ne $false -or (Get-Field $account 'minimumTlsVersion' '') -cne 'TLS1_2' -or (Get-Field $account 'accessTier' '') -cne 'Hot') { throw 'Storage account security settings or access tier differ from the lab specification.' }
    if (@(Get-Field $account 'privateEndpointConnections' @()).Count -gt 0) { throw 'Unexpected private endpoint connections; refusing reuse or deletion.' }
    return Assert-StorageChildren $Context -RequireContainer:$RequireContainer
}

function Get-Inventory {
    param($Context, [switch]$ValidateChildren)
    $resources = Invoke-CheckedAz $Context @('resource', 'list', '--resource-group', $Context.Group, '--subscription', $Context.SubscriptionId)
    $networkFound = $false
    $storageFound = $false
    foreach ($resource in @($resources)) {
        $name = Get-Field $resource 'name' ''
        $type = Get-Field $resource 'type' ''
        if ($Context.Network -and $name -ceq 'vnet-az900' -and $type -ieq 'Microsoft.Network/virtualNetworks') {
            Assert-Ownership $Context $resource $name
            $networkFound = $true
        } elseif ($Context.Storage -and $name -ceq $Context.Account -and $type -ieq 'Microsoft.Storage/storageAccounts') {
            Assert-Ownership $Context $resource $name
            $storageFound = $true
        } elseif ($Context.Network -and $name -ceq 'vnet-az900/subnet-default' -and $type -ieq 'Microsoft.Network/virtualNetworks/subnets') {
            # Subnets cannot be tagged. Their exact parent, names, and properties are checked below.
        } elseif ($Context.Storage -and $name -ceq "$($Context.Account)/default" -and $type -ieq 'Microsoft.Storage/storageAccounts/blobServices') {
        } elseif ($Context.Storage -and $name -ceq "$($Context.Account)/default/practice" -and $type -ieq 'Microsoft.Storage/storageAccounts/blobServices/containers') {
        } else { throw "Unexpected resource in $($Context.Group): $type/$name. Refusing reuse or deletion." }
    }
    $containers = 0
    if ($ValidateChildren) {
        if ($networkFound) { Assert-NetworkState $Context }
        if ($storageFound) { $containers = Assert-StorageState $Context }
    }
    $locks = Invoke-CheckedAz $Context @('lock', 'list', '--resource-group', $Context.Group, '--subscription', $Context.SubscriptionId)
    foreach ($lock in @($locks)) {
        $expectedId = "/subscriptions/$($Context.SubscriptionId)/resourceGroups/$($Context.Group)/providers/Microsoft.Authorization/locks/az900-protection"
        if ($Context.Profile -ne 'governance' -or (Get-Field $lock 'id' '') -ine $expectedId -or (Get-Field $lock 'name' '') -cne 'az900-protection' -or (Get-Field $lock 'level' '') -cne 'CanNotDelete' -or (Get-Field $lock 'notes' '') -cne $Context.LockNotes) { throw 'Unrecognized or inherited resource lock. No lock will be removed.' }
    }
    return [pscustomobject]@{ Network = $networkFound; Storage = $storageFound; Containers = $containers; Locks = @($locks) }
}

function Invoke-Az900Lab {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Preflight', 'Setup', 'Validate', 'Cleanup')][string]$Action,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$LabDirectory,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')][string]$SubscriptionId,
        [Parameter(Mandatory)][ValidatePattern('(?-i)^[a-z][a-z0-9]+$')][string]$Location,
        [Parameter(Mandatory)][ValidatePattern('(?-i)^[a-z0-9]{4,12}$')][string]$RunId,
        [switch]$Execute,
        [switch]$AcknowledgeCost,
        # Internal test seam: wrappers intentionally do not expose these arguments.
        [scriptblock]$AzInvoker,
        [ValidateRange(1, 60)][int]$CleanupAttempts = 30,
        [ValidateRange(0, 60)][int]$PollSeconds = 10
    )
    $metadata = Get-Content -LiteralPath (Join-Path $LabDirectory 'lab.json') -Raw | ConvertFrom-Json
    $id = [string]$metadata.id
    if ($id -notmatch '^\d{2}$') { throw 'Invalid lab ID.' }
    $profile = [string]$metadata.resource_profile
    if ($profile -notin @('resource-group', 'network', 'storage', 'governance', 'bicep', 'capstone')) { throw 'This lab does not have a live resource profile.' }
    $context = [pscustomobject]@{
        Root = Split-Path (Split-Path $LabDirectory -Parent) -Parent
        LabDirectory = $LabDirectory; LabId = $id; Profile = $profile
        SubscriptionId = $SubscriptionId; Location = $Location; RunId = $RunId
        Group = "rg-az900-$id-$RunId"; Account = "staz900$id$RunId"
        Network = $profile -in @('network', 'bicep', 'capstone')
        Storage = $profile -in @('storage', 'capstone')
        Tags = [ordered]@{ 'az900-project' = 'az900-azure-fundamentals-labs'; 'az900-lab' = $id; 'az900-run' = $RunId }
        LockNotes = "az900-project=az900-azure-fundamentals-labs;az900-lab=$id;az900-run=$RunId"
        Invoker = $AzInvoker
    }
    $result = [ordered]@{ lab = $id; run = $RunId; action = $Action; region = $Location; resource_group = $context.Group; status = 'preview'; checked_at_utc = [datetime]::UtcNow.ToString('o') }
    if ($Action -in @('Setup', 'Cleanup') -and -not $Execute) {
        $result['storage_account'] = if ($context.Storage) { $context.Account } else { $null }
        $result['network'] = if ($context.Network) { 'vnet-az900: 10.90.0.0/16; subnet-default: 10.90.1.0/24' } else { $null }
        $result['ownership_tags'] = $context.Tags
        $result['cost_acknowledgment_required'] = $Action -eq 'Setup' -and $context.Storage
        $result['message'] = if ($Action -eq 'Setup') { 'Preview only. No Azure CLI calls. Use -Execute after reviewing names, ownership, permissions, and cost.' } else { 'Preview only. No Azure CLI calls. -Execute deletes this owned resource group and its approved lab contents after inventory checks, including practice blob data.' }
        return [pscustomobject]$result
    }
    if ($Action -eq 'Setup' -and $context.Storage -and -not $AcknowledgeCost) { throw 'Storage deployment requires -Execute -AcknowledgeCost. Review the pricing calculator first.' }
    try {
        Assert-Readiness $context -Deployment:($Action -in @('Setup', 'Preflight'))
        if ($Action -eq 'Preflight') {
            if (Test-GroupExists $context) { $null = Get-OwnedGroup $context; $null = Get-Inventory $context -ValidateChildren }
            $result['status'] = 'ready'
            $result['message'] = 'Read-only readiness checks passed. Permissions, policy, quota, and regional service availability are still enforced by Azure at deployment.'
            Save-Evidence $context 'preflight' $result
            return [pscustomobject]$result
        }
        $exists = Test-GroupExists $context
        if ($Action -eq 'Cleanup' -and -not $exists) {
            $result['status'] = 'absent'; Save-Evidence $context 'cleanup' $result; return [pscustomobject]$result
        }
        if ($exists) { $null = Get-OwnedGroup $context; $inventory = Get-Inventory $context -ValidateChildren }
        elseif ($Action -eq 'Validate') { throw 'Resource group is absent. Run Setup with -Execute first.' }
        else { $inventory = [pscustomobject]@{ Network = $false; Storage = $false; Containers = 0; Locks = @() } }
        if ($Action -eq 'Cleanup') {
            # Re-read ownership and full inventory immediately before the destructive operation.
            $null = Get-OwnedGroup $context
            $inventory = Get-Inventory $context -ValidateChildren
            if ($inventory.Locks.Count -eq 1) { $null = Invoke-CheckedAz $context @('lock', 'delete', '--name', 'az900-protection', '--resource-group', $context.Group, '--subscription', $SubscriptionId) }
            $null = Invoke-CheckedAz $context @('group', 'delete', '--name', $context.Group, '--yes', '--no-wait', '--subscription', $SubscriptionId)
            for ($attempt = 1; $attempt -le $CleanupAttempts; $attempt++) {
                if (-not (Test-GroupExists $context)) {
                    $result['status'] = 'deleted'; Save-Evidence $context 'cleanup' $result; return [pscustomobject]$result
                }
                if ($attempt -lt $CleanupAttempts) { Start-Sleep -Seconds $PollSeconds }
            }
            throw 'Cleanup timed out while the resource group still exists. Inspect Azure, then retry Cleanup; deletion has not been confirmed.'
        }
        if ($Action -eq 'Setup') {
            # Refuse global name collisions before creating even an empty resource group.
            if ($context.Storage -and -not $inventory.Storage) {
                $nameCheck = Invoke-CheckedAz $context @('storage', 'account', 'check-name', '--name', $context.Account, '--subscription', $SubscriptionId)
                if ((Get-Field $nameCheck 'nameAvailable') -ne $true) { throw 'Storage account name is unavailable. Choose a new RunId; no colliding account will be adopted.' }
            }
            $tagArguments = @($context.Tags.Keys | ForEach-Object { "$_=$($context.Tags[$_])" })
            if (-not $exists) {
                $null = Invoke-CheckedAz $context (@('group', 'create', '--name', $context.Group, '--location', $Location, '--tags') + $tagArguments + @('--subscription', $SubscriptionId))
                $null = Get-OwnedGroup $context
            }
            if ($context.Network -and -not $inventory.Network) {
                if ($profile -eq 'bicep') {
                    $null = Invoke-CheckedAz $context @('deployment', 'group', 'create', '--resource-group', $context.Group, '--name', "az900-$id-$RunId", '--template-file', (Join-Path $LabDirectory 'main.bicep'), '--parameters', "location=$Location", "labId=$id", "runId=$RunId", '--subscription', $SubscriptionId)
                } else {
                    $null = Invoke-CheckedAz $context (@('network', 'vnet', 'create', '--resource-group', $context.Group, '--name', 'vnet-az900', '--location', $Location, '--address-prefixes', '10.90.0.0/16', '--subnet-name', 'subnet-default', '--subnet-prefixes', '10.90.1.0/24', '--tags') + $tagArguments + @('--subscription', $SubscriptionId))
                }
            }
            if ($context.Storage -and -not $inventory.Storage) {
                $null = Invoke-CheckedAz $context (@('storage', 'account', 'create', '--resource-group', $context.Group, '--name', $context.Account, '--location', $Location, '--kind', 'StorageV2', '--sku', 'Standard_LRS', '--access-tier', 'Hot', '--https-only', 'true', '--min-tls-version', 'TLS1_2', '--allow-blob-public-access', 'false', '--tags') + $tagArguments + @('--subscription', $SubscriptionId))
                $inventory.Containers = Assert-StorageState $context
            }
            if ($context.Storage -and $inventory.Containers -eq 0) {
                $null = Invoke-CheckedAz $context @('storage', 'container-rm', 'create', '--resource-group', $context.Group, '--storage-account', $context.Account, '--name', 'practice', '--public-access', 'off', '--metadata', 'az900_project=az900-azure-fundamentals-labs', "az900_lab=$id", "az900_run=$RunId", '--subscription', $SubscriptionId)
            }
            if ($profile -eq 'governance' -and $inventory.Locks.Count -eq 0) {
                $null = Invoke-CheckedAz $context @('lock', 'create', '--resource-group', $context.Group, '--name', 'az900-protection', '--lock-type', 'CanNotDelete', '--notes', $context.LockNotes, '--subscription', $SubscriptionId)
            }
        }
        $null = Get-OwnedGroup $context
        $inventory = Get-Inventory $context -ValidateChildren
        if ($context.Network -and -not $inventory.Network) { throw 'Expected virtual network is missing.' }
        if ($context.Storage -and (-not $inventory.Storage -or $inventory.Containers -ne 1)) { throw 'Expected storage account or private practice container is missing.' }
        if ($profile -eq 'governance' -and $inventory.Locks.Count -ne 1) { throw 'Expected owned CanNotDelete lock is missing.' }
        $result['status'] = 'validated'
        $result['message'] = 'Owned lab resources and expected properties validated. Optional blob data is removed with Cleanup.'
        Save-Evidence $context 'validation' $result
        return [pscustomobject]$result
    } catch {
        $result['status'] = 'failed'
        # Evidence excludes CLI error bodies and subscription/tenant IDs.
        $result['message'] = 'Operation failed or safety check refused it. Read the console error and inspect Azure before retrying.'
        $evidenceName = if ($Action -eq 'Preflight') { 'preflight' } elseif ($Action -eq 'Cleanup') { 'cleanup' } else { 'validation' }
        Save-Evidence $context $evidenceName $result
        throw
    }
}

Export-ModuleMember -Function Invoke-Az900Lab
