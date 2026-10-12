#requires -Version 7.4
<#
.SYNOPSIS
Setup the named AZ-900 lab run. Setup and Cleanup preview by default.
.DESCRIPTION
Requires an explicit subscription GUID, canonical region, and lowercase run ID.
Preflight and Validate are read-only. Execution refuses ownership or inventory mismatches.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')][string]$SubscriptionId,
    [Parameter(Mandatory)][ValidatePattern('(?-i)^[a-z][a-z0-9]+$')][string]$Location,
    [Parameter(Mandatory)][ValidatePattern('(?-i)^[a-z0-9]{4,12}$')][string]$RunId,
    [switch]$Execute,
    [switch]$AcknowledgeCost
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../tools/LabRuntime.psm1') -Force
Invoke-Az900Lab -Action 'Setup' -LabDirectory $PSScriptRoot -SubscriptionId $SubscriptionId -Location $Location -RunId $RunId -Execute:$Execute -AcknowledgeCost:$AcknowledgeCost
