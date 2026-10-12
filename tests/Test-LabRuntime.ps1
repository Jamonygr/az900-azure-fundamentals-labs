#requires -Version 7.4
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$projectRoot = Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $projectRoot 'tools/LabRuntime.psm1') -Force
$subscription = '11111111-1111-1111-1111-111111111111'
$passed = 0

function Assert-True { param([bool]$Condition, [string]$Message) if (-not $Condition) { throw $Message } }
function Assert-Throws {
    param([scriptblock]$Body, [string]$Pattern)
    $caught = $null
    try { & $Body | Out-Null } catch { $caught = $_ }
    if ($null -eq $caught -or $caught.Exception.Message -notmatch $Pattern) { throw "Expected failure matching '$Pattern'; observed '$caught'." }
}
function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    & $Body
    $script:passed++
    Write-Host "PASS $Name"
}
function New-Fixture {
    param([string]$LabId = '06')
    $directory = (Get-ChildItem -LiteralPath (Join-Path $projectRoot 'labs') -Directory | Where-Object Name -Like "$LabId-*").FullName
    $group = "rg-az900-$LabId-test01"
    $tags = [ordered]@{ 'az900-project' = 'az900-azure-fundamentals-labs'; 'az900-lab' = $LabId; 'az900-run' = 'test01' }
    $state = [pscustomobject]@{
        Directory = $directory; LabId = $LabId; Group = $group; Tags = $tags; Location = 'eastus'
        Subscription = $subscription; Environment = 'AzureCloud'; Enabled = $true; Registered = $true; NameAvailable = $true
        GroupExists = $false; Network = $null; Storage = $null; Containers = @(); Shares = @(); Queues = @(); Tables = @(); Locks = @(); Extra = @()
        Calls = [System.Collections.Generic.List[string]]::new(); FailCommand = ''; BadJson = $false; BadInventory = $false; NextLink = ''
        Deleting = $false; DeleteRemaining = 0; Residual = $false
    }
    $invoker = {
        param([string[]]$Arguments)
        function Arg { param([string]$Name) $index = [array]::IndexOf($Arguments, $Name); if ($index -lt 0) { return '' }; return $Arguments[$index + 1] }
        $command = $Arguments -join ' '
        $state.Calls.Add($command)
        if ($state.FailCommand -and $command.StartsWith($state.FailCommand)) { return @{ ExitCode = 1; Output = 'fixture error with learner details that must never enter evidence' } }
        if ($state.BadJson) { return @{ ExitCode = 0; Output = '{invalid' } }
        $value = $null
        if ($command.StartsWith('account show')) { $value = @{ id = $state.Subscription; environmentName = $state.Environment; state = $(if ($state.Enabled) { 'Enabled' } else { 'Disabled' }) } }
        elseif ($command.StartsWith('account list-locations')) { $value = @(@{ name = 'eastus' }, @{ name = 'westeurope' }) }
        elseif ($command.StartsWith('provider show')) { $value = @{ registrationState = $(if ($state.Registered) { 'Registered' } else { 'NotRegistered' }) } }
        elseif ($command.StartsWith('bicep version')) { return @{ ExitCode = 0; Output = 'Bicep CLI version 0.46.1' } }
        elseif ($command.StartsWith('group exists')) {
            if ($state.Deleting -and -not $state.Residual) {
                if ($state.DeleteRemaining -eq 0) { $state.GroupExists = $false } else { $state.DeleteRemaining-- }
            }
            $value = $state.GroupExists
        }
        elseif ($command.StartsWith('group show')) { $value = @{ name = $state.Group; location = $state.Location; tags = $state.Tags } }
        elseif ($command.StartsWith('group create')) { $state.GroupExists = $true; $value = @{} }
        elseif ($command.StartsWith('group delete')) { $state.Deleting = $true }
        elseif ($command.StartsWith('resource list')) {
            $value = @()
            if ($null -ne $state.Network) { $value += @{ name = 'vnet-az900'; type = 'Microsoft.Network/virtualNetworks'; tags = $state.Network.tags } }
            if ($null -ne $state.Storage) { $value += @{ name = $state.Storage.name; type = 'Microsoft.Storage/storageAccounts'; tags = $state.Storage.tags } }
            $value += $state.Extra
        }
        elseif ($command.StartsWith('network vnet create') -or $command.StartsWith('deployment group create')) {
            $state.Network = @{ name = 'vnet-az900'; location = $state.Location; tags = $state.Tags; addressSpace = @{ addressPrefixes = @('10.90.0.0/16') }; subnets = @(@{ name = 'subnet-default'; addressPrefix = '10.90.1.0/24' }); virtualNetworkPeerings = @() }
            $value = @{}
        }
        elseif ($command.StartsWith('network vnet show')) { $value = $state.Network }
        elseif ($command.StartsWith('storage account check-name')) { $value = @{ nameAvailable = $state.NameAvailable } }
        elseif ($command.StartsWith('storage account create')) {
            $state.Storage = @{ name = (Arg '--name'); location = $state.Location; tags = $state.Tags; kind = 'StorageV2'; sku = @{ name = 'Standard_LRS' }; enableHttpsTrafficOnly = $true; allowBlobPublicAccess = $false; minimumTlsVersion = 'TLS1_2'; accessTier = 'Hot' }
            $value = $state.Storage
        }
        elseif ($command.StartsWith('storage account show')) { $value = $state.Storage }
        elseif ($command.StartsWith('storage container-rm list')) { $value = $state.Containers }
        elseif ($command.StartsWith('storage container-rm create')) {
            $state.Containers = @(@{ name = 'practice'; publicAccess = 'None'; metadata = @{ az900_project = 'az900-azure-fundamentals-labs'; az900_lab = $state.LabId; az900_run = 'test01' } })
            $value = $state.Containers[0]
        }
        elseif ($command.StartsWith('storage share-rm list')) { $value = $state.Shares }
        elseif ($command.StartsWith('rest --method get')) {
            $children = @(if ((Arg '--url') -match '/queueServices/') { $state.Queues } else { $state.Tables })
            $value = if ($state.BadInventory) { @{} } else { @{ value = $children; nextLink = $state.NextLink } }
        }
        elseif ($command.StartsWith('lock list')) { $value = $state.Locks }
        elseif ($command.StartsWith('lock create')) {
            $state.Locks = @(@{ id = "/subscriptions/$($state.Subscription)/resourceGroups/$($state.Group)/providers/Microsoft.Authorization/locks/az900-protection"; name = 'az900-protection'; level = 'CanNotDelete'; notes = (Arg '--notes') })
            $value = $state.Locks[0]
        }
        elseif ($command.StartsWith('lock delete')) { $state.Locks = @() }
        else { throw "Unrecognized fixture command: $command" }
        return @{ ExitCode = 0; Output = (ConvertTo-Json -InputObject $value -Depth 30 -Compress) }
    }.GetNewClosure()
    return [pscustomobject]@{
        State = $state
        Parameters = @{ LabDirectory = $directory; SubscriptionId = $subscription; Location = 'eastus'; RunId = 'test01'; AzInvoker = $invoker; CleanupAttempts = 3; PollSeconds = 0 }
    }
}
function Setup-Fixture {
    param($Fixture)
    $parameters = $Fixture.Parameters
    Invoke-Az900Lab @parameters -Action Setup -Execute -AcknowledgeCost | Out-Null
}
function Assert-NoMutations {
    param($Fixture)
    Assert-True (-not @($Fixture.State.Calls | Where-Object { $_ -match '^(group (create|delete)|network vnet create|deployment group create|storage (account create|container-rm create)|lock (create|delete))' }).Count) 'Unexpected mutation command.'
}

Test-Case 'all sixteen Setup/Cleanup previews issue zero CLI calls' {
    foreach ($id in @('06','08','09','10','14','15','18','21')) {
        $fixture = New-Fixture $id; $parameters = $fixture.Parameters
        foreach ($action in @('Setup','Cleanup')) {
            $result = Invoke-Az900Lab @parameters -Action $action
            Assert-True ($result.status -eq 'preview') 'Preview status missing.'
        }
        Assert-True ($fixture.State.Calls.Count -eq 0) 'Preview contacted Azure.'
    }
}
Test-Case 'empty subscription, empty location, invalid GUID, and invalid run ID fail before CLI' {
    $fixture = New-Fixture
    foreach ($override in @(@{ SubscriptionId = '' }, @{ SubscriptionId = 'not-a-guid' }, @{ Location = '' }, @{ RunId = '../outside' }, @{ RunId = 'STUDY01' })) {
        $parameters = $fixture.Parameters.Clone()
        foreach ($key in $override.Keys) { $parameters[$key] = $override[$key] }
        Assert-Throws { Invoke-Az900Lab @parameters -Action Setup -Execute } 'validate argument|validation|empty string'
    }
    Assert-True ($fixture.State.Calls.Count -eq 0) 'Invalid parameters contacted Azure.'
}
Test-Case 'storage cost acknowledgment is required before CLI; Cleanup remains previewable' {
    $fixture = New-Fixture '09'; $parameters = $fixture.Parameters
    Assert-Throws { Invoke-Az900Lab @parameters -Action Setup -Execute } 'AcknowledgeCost'
    Assert-True ($fixture.State.Calls.Count -eq 0) 'Cost refusal contacted Azure.'
    $null = Invoke-Az900Lab @parameters -Action Cleanup
}
Test-Case 'Azure login failure and invalid JSON fail before mutations' {
    $fixture = New-Fixture; $parameters = $fixture.Parameters
    $fixture.State.FailCommand = 'account show'
    Assert-Throws { Invoke-Az900Lab @parameters -Action Setup -Execute } 'Azure CLI failed'
    Assert-NoMutations $fixture
    $fixture.State.FailCommand = ''; $fixture.State.BadJson = $true
    Assert-Throws { Invoke-Az900Lab @parameters -Action Setup -Execute } 'invalid JSON'
}
Test-Case 'subscription mismatch and disabled subscription are refused' {
    $fixture = New-Fixture; $parameters = $fixture.Parameters
    $fixture.State.Subscription = '22222222-2222-2222-2222-222222222222'
    Assert-Throws { Invoke-Az900Lab @parameters -Action Setup -Execute } 'Subscription mismatch'
    $fixture.State.Subscription = $subscription; $fixture.State.Enabled = $false
    Assert-Throws { Invoke-Az900Lab @parameters -Action Setup -Execute } 'not enabled'
    Assert-NoMutations $fixture
}
Test-Case 'sovereign and unknown cloud contexts are refused before mutations' {
    $fixture = New-Fixture; $parameters = $fixture.Parameters
    foreach ($cloud in @('AzureUSGovernment','AzureChinaCloud','')) {
        $fixture.State.Environment = $cloud
        Assert-Throws { Invoke-Az900Lab @parameters -Action Setup -Execute } 'Unsupported cloud context'
    }
    Assert-NoMutations $fixture
}
Test-Case 'unknown region and unregistered provider refuse deployment' {
    $fixture = New-Fixture '08'; $parameters = $fixture.Parameters.Clone(); $parameters.Location = 'imaginaryregion'
    Assert-Throws { Invoke-Az900Lab @parameters -Action Setup -Execute } 'Unknown region'
    $parameters.Location = 'eastus'; $fixture.State.Registered = $false
    Assert-Throws { Invoke-Az900Lab @parameters -Action Setup -Execute } 'not registered'
    Assert-NoMutations $fixture
}
Test-Case 'foreign ownership and wrong resource group region refuse cleanup and setup' {
    $fixture = New-Fixture; $parameters = $fixture.Parameters; $fixture.State.GroupExists = $true
    $fixture.State.Tags['az900-run'] = 'another'
    Assert-Throws { Invoke-Az900Lab @parameters -Action Cleanup -Execute } 'Ownership refusal'
    $fixture.State.Tags['az900-run'] = 'test01'; $fixture.State.Location = 'westeurope'
    Assert-Throws { Invoke-Az900Lab @parameters -Action Setup -Execute } 'region differs'
    Assert-NoMutations $fixture
}
Test-Case 'foreign resources and foreign locks prevent group deletion' {
    $fixture = New-Fixture; $parameters = $fixture.Parameters; $fixture.State.GroupExists = $true
    $fixture.State.Extra = @(@{ name = 'unrelated-vm'; type = 'Microsoft.Compute/virtualMachines'; tags = @{} })
    Assert-Throws { Invoke-Az900Lab @parameters -Action Cleanup -Execute } 'Unexpected resource'
    $fixture.State.Extra = @(); $fixture.State.Locks = @(@{ name = 'unrelated'; id = 'other-scope'; level = 'CanNotDelete'; notes = 'other' })
    Assert-Throws { Invoke-Az900Lab @parameters -Action Cleanup -Execute } 'Unrecognized or inherited'
    Assert-NoMutations $fixture
}
Test-Case 'network setup and rerun are stable; extra subnet and changed tags are refused' {
    $fixture = New-Fixture '08'; $parameters = $fixture.Parameters
    Setup-Fixture $fixture
    $fixture.State.Calls.Clear()
    $null = Invoke-Az900Lab @parameters -Action Setup -Execute
    Assert-NoMutations $fixture
    $fixture.State.Network.subnets += @{ name = 'unrelated'; addressPrefix = '10.90.2.0/24' }
    Assert-Throws { Invoke-Az900Lab @parameters -Action Cleanup -Execute } 'Unexpected virtual network'
    Assert-NoMutations $fixture
    $fixture.State.Network.subnets = @($fixture.State.Network.subnets[0]); $fixture.State.Network.tags = @{ 'az900-project' = 'foreign' }
    Assert-Throws { Invoke-Az900Lab @parameters -Action Cleanup -Execute } 'Ownership refusal'
}
Test-Case 'storage name collision refuses even resource group creation' {
    $fixture = New-Fixture '09'; $parameters = $fixture.Parameters; $fixture.State.NameAvailable = $false
    Assert-Throws { Invoke-Az900Lab @parameters -Action Setup -Execute -AcknowledgeCost } 'name is unavailable'
    Assert-NoMutations $fixture
}
Test-Case 'storage rerun is stable and all mutation commands contain subscription and secure flags' {
    $fixture = New-Fixture '09'; $parameters = $fixture.Parameters
    Setup-Fixture $fixture
    $create = @($fixture.State.Calls | Where-Object { $_ -like 'storage account create*' })[0]
    foreach ($expected in @('--sku Standard_LRS','--kind StorageV2','--https-only true','--allow-blob-public-access false','--min-tls-version TLS1_2','--access-tier Hot')) { Assert-True ($create.Contains($expected)) "Missing $expected." }
    foreach ($command in $fixture.State.Calls) { if ($command -notlike 'account show*') { Assert-True ($command.Contains("--subscription $subscription")) 'Missing explicit subscription.' } }
    $fixture.State.Calls.Clear(); $null = Invoke-Az900Lab @parameters -Action Setup -Execute -AcknowledgeCost
    Assert-NoMutations $fixture
}
Test-Case 'storage unexpected container, metadata, shares, queues, and tables stop deletion' {
    $fixture = New-Fixture '09'; $parameters = $fixture.Parameters
    Setup-Fixture $fixture; $fixture.State.Calls.Clear()
    $fixture.State.Containers += @{ name = 'unrelated' }
    Assert-Throws { Invoke-Az900Lab @parameters -Action Cleanup -Execute } 'Unexpected blob container'
    $fixture.State.Containers = @($fixture.State.Containers[0]); $fixture.State.Containers[0].metadata.az900_run = 'foreign'
    Assert-Throws { Invoke-Az900Lab @parameters -Action Cleanup -Execute } 'ownership metadata'
    $fixture.State.Containers[0].metadata.az900_run = 'test01'
    $fixture.State.Shares = @(@{ name = 'foreign-share' })
    Assert-Throws { Invoke-Az900Lab @parameters -Action Cleanup -Execute } 'Unexpected file shares'
    $fixture.State.Shares = @(); $fixture.State.Queues = @(@{ name = 'foreign-queue' })
    Assert-Throws { Invoke-Az900Lab @parameters -Action Cleanup -Execute } 'Unexpected queue'
    $fixture.State.Queues = @(); $fixture.State.Tables = @(@{ name = 'foreign-table' })
    Assert-Throws { Invoke-Az900Lab @parameters -Action Cleanup -Execute } 'Unexpected table'
    Assert-NoMutations $fixture
}
Test-Case 'changed storage security settings fail validation' {
    $fixture = New-Fixture '09'; $parameters = $fixture.Parameters
    Setup-Fixture $fixture; $fixture.State.Calls.Clear(); $fixture.State.Storage.allowBlobPublicAccess = $true
    Assert-Throws { Invoke-Az900Lab @parameters -Action Validate } 'security settings'
    Assert-NoMutations $fixture
}
Test-Case 'incomplete storage inventory and private endpoint associations refuse deletion' {
    $fixture = New-Fixture '09'; $parameters = $fixture.Parameters
    Setup-Fixture $fixture; $fixture.State.Calls.Clear(); $fixture.State.BadInventory = $true
    Assert-Throws { Invoke-Az900Lab @parameters -Action Cleanup -Execute } 'Unrecognized queue inventory'
    $fixture.State.BadInventory = $false; $fixture.State.NextLink = 'https://management.azure.com/next-page'
    Assert-Throws { Invoke-Az900Lab @parameters -Action Cleanup -Execute } 'pagination'
    $fixture.State.NextLink = ''; $fixture.State.Storage.privateEndpointConnections = @(@{ id = 'foreign-connection' })
    Assert-Throws { Invoke-Az900Lab @parameters -Action Cleanup -Execute } 'Unexpected private endpoint'
    Assert-NoMutations $fixture
}
Test-Case 'governance removes only its own verified lock before deleting its empty group' {
    $fixture = New-Fixture '15'; $parameters = $fixture.Parameters
    Setup-Fixture $fixture; $fixture.State.Calls.Clear()
    $result = Invoke-Az900Lab @parameters -Action Cleanup -Execute
    Assert-True ($result.status -eq 'deleted') 'Deletion not verified.'
    $commands = $fixture.State.Calls.ToArray()
    $lockIndex = [array]::FindIndex($commands, [Predicate[string]]{ param($value) $value.StartsWith('lock delete') })
    $groupIndex = [array]::FindIndex($commands, [Predicate[string]]{ param($value) $value.StartsWith('group delete') })
    Assert-True ($lockIndex -ge 0 -and $groupIndex -gt $lockIndex) 'Lock removal order is wrong.'
}
Test-Case 'Bicep lab and capstone setup validate the expected resources' {
    foreach ($id in @('18','21')) {
        $fixture = New-Fixture $id; Setup-Fixture $fixture
        Assert-True ($null -ne $fixture.State.Network) 'Network missing.'
        if ($id -eq '18') { Assert-True (@($fixture.State.Calls | Where-Object { $_ -like 'deployment group create*' }).Count -eq 1) 'Bicep deployment missing.' }
        if ($id -eq '21') { Assert-True ($null -ne $fixture.State.Storage) 'Capstone storage missing.' }
    }
}
Test-Case 'Preflight and Validate use only reads; absent validation fails' {
    $fixture = New-Fixture '06'; $parameters = $fixture.Parameters
    $null = Invoke-Az900Lab @parameters -Action Preflight
    Assert-Throws { Invoke-Az900Lab @parameters -Action Validate } 'absent'
    Assert-NoMutations $fixture
    Setup-Fixture $fixture; $fixture.State.Calls.Clear()
    $null = Invoke-Az900Lab @parameters -Action Validate
    Assert-NoMutations $fixture
}
Test-Case 'failed creation preserves failure and allows a checked retry' {
    $fixture = New-Fixture '08'; $parameters = $fixture.Parameters; $fixture.State.FailCommand = 'network vnet create'
    Assert-Throws { Invoke-Az900Lab @parameters -Action Setup -Execute } 'Azure CLI failed'
    Assert-True $fixture.State.GroupExists 'Created empty group should remain visible.'
    Assert-True ($null -eq $fixture.State.Network) 'Failed creation assumed successful.'
    $fixture.State.FailCommand = ''; Setup-Fixture $fixture
    Assert-True ($null -ne $fixture.State.Network) 'Retry did not recover.'
}
Test-Case 'failed cleanup never reports success; residual existence times out' {
    $fixture = New-Fixture; $parameters = $fixture.Parameters; Setup-Fixture $fixture
    $fixture.State.FailCommand = 'group delete'
    Assert-Throws { Invoke-Az900Lab @parameters -Action Cleanup -Execute } 'Azure CLI failed'
    $fixture.State.FailCommand = ''; $fixture.State.Residual = $true
    Assert-Throws { Invoke-Az900Lab @parameters -Action Cleanup -Execute } 'timed out'
    $fixture.State.Residual = $false; $fixture.State.DeleteRemaining = 1
    $result = Invoke-Az900Lab @parameters -Action Cleanup -Execute
    Assert-True ($result.status -eq 'deleted') 'Delayed deletion not verified.'
    $result = Invoke-Az900Lab @parameters -Action Cleanup -Execute
    Assert-True ($result.status -eq 'absent') 'Repeated cleanup should confirm absence.'
}
Test-Case 'evidence excludes subscriptions and raw Azure error bodies' {
    $fixture = New-Fixture; $parameters = $fixture.Parameters; $fixture.State.FailCommand = 'account show'
    Assert-Throws { Invoke-Az900Lab @parameters -Action Preflight } 'Azure CLI failed'
    $evidence = Get-Content -LiteralPath (Join-Path $projectRoot 'evidence/06/test01/preflight.json') -Raw
    Assert-True (-not $evidence.Contains($subscription)) 'Subscription leaked into evidence.'
    Assert-True (-not $evidence.Contains('fixture error')) 'Raw CLI error leaked into evidence.'
}

Write-Host "$passed lifecycle tests passed. No Azure service was contacted. Test evidence is ignored by Git."
