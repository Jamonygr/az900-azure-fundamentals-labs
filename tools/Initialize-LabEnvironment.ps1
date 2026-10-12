#requires -Version 7.4
<#
.SYNOPSIS
Report the learner tool environment without installing tools or signing in.
#>
[CmdletBinding()]
param([switch]$RequireBicep)
$ErrorActionPreference = 'Stop'
$report = [ordered]@{
    PowerShell = $PSVersionTable.PSVersion.ToString()
    AzureCli = [bool](Get-Command az -ErrorAction SilentlyContinue)
    Bicep = 'Not checked; required only for Lab 18 or optional capstone template compilation.'
    Authentication = 'Not checked. Run az login yourself, then az account set --subscription <your-subscription-guid>.'
    ExampleInputs = 'SubscriptionId=<your-subscription-guid>; Location=<canonical-region>; RunId=study01'
}
if (-not $report.AzureCli) { throw 'Azure CLI is missing. Follow the official installation link in Lab 00; this script does not install it.' }
if ($RequireBicep) {
    $previous = $env:AZURE_BICEP_CHECK_VERSION
    try {
        $env:AZURE_BICEP_CHECK_VERSION = 'false'
        $version = (& az bicep version --only-show-errors 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $version -notmatch 'Bicep CLI version') { throw 'An existing Azure CLI Bicep installation is missing. Run az bicep install explicitly if you choose Lab 18.' }
        $report.Bicep = $version
    } finally { $env:AZURE_BICEP_CHECK_VERSION = $previous }
}
[pscustomobject]$report
