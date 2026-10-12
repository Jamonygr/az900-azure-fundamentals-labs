# Lab 21 — Integrated Azure fundamentals capstone

**Duration:** 90 minutes · **Route:** live Azure · **Verification:** offline-validated; author live testing not performed.

## Objectives

Integrate resource hierarchy, networking, storage, tags, cost reasoning, governance, monitoring, and ownership-aware cleanup. This capstone revisits earlier objective IDs without adding new exam topics or a separate question bank.

## Prerequisites

Complete Labs 00–20. Use PowerShell 7.4+, Azure CLI, an approved subscription, a permitted region, and permission to create the owned group and its network/storage resources. Storage charges are possible; review the [cost guidance](../../docs/cost-cleanup.md). Do not enable paid plans or add unrelated resources. Blob transfer, if attempted, also needs legitimate Entra data-plane permission; it is not needed for the management-plane completion checks.

## Scenario

A small company wants a disposable proof of concept for private document storage and a future application network. It wants predictable ownership, minimal infrastructure, a management activity trail, and removal after review. You must justify each service choice, prove the deployed configuration, diagnose an observation, and finish with no active lab resource group.

## Concept primer

The resource group is a lifecycle boundary, not a network boundary. A VNet defines address space; it does not automatically connect every resource placed in the same group. A private blob container prevents anonymous blob access but is different from a private endpoint. The storage account in this lab retains a public service endpoint with authorized access; this is a deliberate low-complexity design choice. Explain what a private endpoint would change without deploying one.

Standard_LRS stores redundant copies within its local replication boundary; it does not provide geo-replication. Tags organize the deployment but do not enforce every governance rule or propagate automatically. Activity Log records management operations; it is different from application telemetry or blob request logs. Ownership and cleanup checks are as much part of this project as successful creation.

## Guided exercise

Define fresh, explicit inputs and review your design decisions:

```powershell
$SubscriptionId = Read-Host 'Approved disposable subscription GUID'
$Location = Read-Host 'Approved Azure region'
$RunId = 'final001'
$ResourceGroup = "rg-az900-21-$RunId"
$StorageAccount = "staz90021$RunId"
az account show --query '{Name:name,Id:id}' -o json
```

In your private notes, compare a VM, a container, and a Function for the future app; select one and explain which responsibilities remain with the company. Identify the scope of an RBAC grant, a Policy rule, and a resource lock. Estimate the storage operation and capacity drivers using current pricing rather than assuming this exercise is free.

Run readiness and inspect the setup preview:

```powershell
./Preflight.ps1 -SubscriptionId $SubscriptionId -Location $Location -RunId $RunId
./Setup.ps1 -SubscriptionId $SubscriptionId -Location $Location -RunId $RunId
```

These lab-local calls assume your working directory is `labs/21-integrated-capstone`. Check the group, network, storage account, region, and ownership tags in the preview. After review, deploy:

```powershell
./Setup.ps1 -SubscriptionId $SubscriptionId -Location $Location -RunId $RunId -Execute -AcknowledgeCost
./Validate.ps1 -SubscriptionId $SubscriptionId -Location $Location -RunId $RunId
az resource list --resource-group $ResourceGroup --subscription $SubscriptionId -o table
az network vnet show --resource-group $ResourceGroup --name vnet-az900 --subscription $SubscriptionId --query '{Address:addressSpace.addressPrefixes,Subnets:subnets[].addressPrefix}' -o json
az storage account show --resource-group $ResourceGroup --name $StorageAccount --subscription $SubscriptionId --query '{Kind:kind,Sku:sku.name,Tls:minimumTlsVersion,Https:enableHttpsTrafficOnly,Anonymous:allowBlobPublicAccess}' -o json
```

Expected observations: VNet `10.90.0.0/16`, subnet `10.90.1.0/24`, StorageV2/Standard_LRS, TLS 1.2 minimum, HTTPS required, and anonymous blob access disabled. Explain why none of these settings alone proves a workload meets all business continuity requirements.

Inspect management activity:

```powershell
az monitor activity-log list --resource-group $ResourceGroup --subscription $SubscriptionId --offset 2h --query '[].{Time:eventTimestamp,Operation:operationName.value,Status:status.value}' -o table
```

Entries may arrive after a delay. If empty, check time range and permissions and describe that observation accurately. Use a clearly labeled example from Lab 20 to propose an application alert; do not enable ingestion.

For a negative reasoning check, ask whether anonymous blob access is allowed and whether sharing the resource group places storage in the subnet. Both claims should be rejected. Do not deliberately expose data or deploy extra resources to demonstrate the failure.

## Expected results

- Your design decisions identify service model, hierarchy, endpoint, redundancy, cost drivers, and governance boundaries.
- Script validation passes all required configuration checks for the owned network and storage resources.
- You distinguish management Activity Log evidence from application or data-plane logs.
- Cleanup completes and the owned resource group is absent.

## Knowledge check

Use this completion checklist: written design justification; reviewed setup preview; successful live setup; successful validation; redacted observation record; explained negative checks; reviewed cleanup preview; completed cleanup; confirmed absence. If any required check fails, mark the capstone incomplete and record the unresolved issue.

## Troubleshooting

If the storage name is globally unavailable, choose a fresh run ID and rerun preflight. If validation reports an unexpected VNet/subnet or account setting, inspect the exact owned resource and compare it with the expected configuration before deciding on a repair. Do not treat an empty Activity Log or absent Advisor recommendation as proof that the deployment never existed. If ownership or inventory refusal occurs, investigate rather than retagging resources to bypass it.

## Cleanup

```powershell
./Cleanup.ps1 -SubscriptionId $SubscriptionId -Location $Location -RunId $RunId
./Cleanup.ps1 -SubscriptionId $SubscriptionId -Location $Location -RunId $RunId -Execute
az group exists --name $ResourceGroup --subscription $SubscriptionId
```

The final result must be `false`. Cleanup removes only the expected owned resources; failures or residual resources keep the capstone incomplete. Check later billing for usage already incurred. Keep redacted evidence privately in the ignored evidence directory.

## References

- [Resource groups](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-cli)
- [Virtual networks](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview)
- [Storage redundancy](https://learn.microsoft.com/en-us/azure/storage/common/storage-redundancy)
- [Activity Log](https://learn.microsoft.com/en-us/azure/azure-monitor/platform/activity-log)
- [Objective map](../../docs/objective-map.md)
