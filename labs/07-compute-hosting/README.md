# Lab 07 — Compute and application hosting choices

45 minutes · Read-only Azure inspection · Offline-validated

## Objectives

- **A08:** Compare VMs, containers, and functions.
- **A09–A10:** Explain VM options and required components.
- **A11:** Choose a hosting approach for an application.

## Prerequisites

Complete Lab 06. Use PowerShell 7.4+ and authenticated Azure CLI with read access to your selected subscription. No VM, cluster, app plan, or function is created.

## Scenario

A publisher needs an old desktop application, a custom website, and a short file-processing job. Inspect available VM information, but make hosting decisions before provisioning anything.

## Concept primer

A VM supplies a guest OS you control. Its core components include a size, OS image/disk, network interface, subnet/virtual network, and identity/security configuration. A public IP is optional. Persistent data disks may be added; temporary disks are not durable storage. VM Scale Sets manage a group of VM instances and support scaling. Availability sets distribute instances across fault/update domains; availability zones separate physical failure boundaries inside a region. Multiple instances and application-level failover are still needed.

Azure Virtual Desktop delivers virtual desktops and applications through VM session hosts organized into host pools. Choose it when people need a managed desktop access experience; distinguish it from hosting a public website. The organization still manages its session-host images, applications, and access configuration.

Containers package an application and dependencies while sharing the host kernel. Azure Container Instances runs containers without your own VM management; Azure Kubernetes Service orchestrates container workloads. Functions runs triggered code on a managed platform. App Service provides managed hosting for websites/APIs, including supported code runtimes and containers. Select using control, packaging, scaling, and maintenance requirements, not service popularity.

## Guided exercise

```powershell
$SubscriptionId = 'YOUR-SUBSCRIPTION-GUID'
$Location = 'YOUR-APPROVED-REGION'
az account show --subscription $SubscriptionId --query '{id:id,name:name}' -o json
az vm list-skus --location $Location --resource-type virtualMachines --subscription $SubscriptionId --query '[].{Name:name,Tier:tier,Capabilities:capabilities,Restrictions:restrictions}' -o json
az vm list-usage --location $Location --subscription $SubscriptionId -o table
```

1. Choose two returned sizes and compare their `Capabilities` fields, such as vCPUs and memory. Names alone are not a price list or a guarantee of capacity.
2. Explain the difference between a listed SKU, subscription quota, restrictions, and actual deployable capacity. None of these read operations allocates a VM.
3. Write a three-row local decision log: legacy OS customization → VM; managed website → App Service; upload-triggered task → Functions. For each, state who maintains the OS and application code.
4. Break-fix a proposed design: one VM in one availability zone is claimed to survive that zone's failure. Correct it with multiple-zone instances and a service/failover design, or a suitable zone-redundant managed service.
5. Verify: list the VM's mandatory networking/storage components and cross out `public IP required`. Explain how private management connectivity can replace internet exposure.

## Expected results

You have current read-only SKU/quota observations and three hosting decisions. You understand that availability sets, zones, and scale sets solve different problems.

## Knowledge check

Complete [the 30 questions](questions.json). Explain why packaging a container does not itself choose between a self-managed host and a managed service.

## Troubleshooting

A long SKU response is normal. Capture it only to an ignored local evidence directory. A SKU restriction or quota limit is not a request to deploy in a random region; retain governance/residency constraints. If CLI returns an error, inspect `$LASTEXITCODE` before interpreting the output.

## Cleanup

No resources were created. Delete optional local evidence containing subscription metadata when finished.

## References

- [Azure compute concepts](https://learn.microsoft.com/en-us/training/modules/describe-azure-compute-networking-services/)
- [Virtual machines](https://learn.microsoft.com/en-us/azure/virtual-machines/overview)
- [VM Scale Sets](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/overview)
- [Azure Virtual Desktop](https://learn.microsoft.com/en-us/azure/virtual-desktop/overview)
- [App Service](https://learn.microsoft.com/en-us/azure/app-service/overview)
- [Azure Functions](https://learn.microsoft.com/en-us/azure/azure-functions/functions-overview)
- [Azure Container Instances](https://learn.microsoft.com/en-us/azure/container-instances/container-instances-overview)
