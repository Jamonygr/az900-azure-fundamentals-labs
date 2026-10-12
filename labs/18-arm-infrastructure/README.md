# Lab 18 — ARM and infrastructure as code

**50 minutes · Owned Bicep network deployment · Offline-validated**

## Objectives

- **M11:** Explain repeatability, review, parameters, and drift in infrastructure as code.
- **M12:** Explain Azure Resource Manager, ARM templates, and Bicep.

## Prerequisites

Complete [Lab 00](../00-safe-start/README.md) and [Lab 08](../08-virtual-networking/README.md). Use PowerShell 7.4+, Azure CLI with available Bicep tooling, and permission to deploy resources in a lab group. `Microsoft.Network` must already be registered; the lab does not register providers. Supply an explicit subscription, region, and fresh run ID. Run commands from the repository root.

## Scenario

A team wants to recreate a simple private network consistently. Inspect a versioned Bicep definition, compile it, deploy through the guarded lifecycle wrapper, and compare the resulting address space with the intended state. The template creates a VNet and subnet, not VMs, gateways, paid monitoring workspaces, or public endpoints.

## Concept primer

Azure Resource Manager is the Azure resource-management layer used by tools such as the portal, CLI, PowerShell, and APIs. It processes deployment and management requests while applicable permissions, policies, and locks still apply. An ARM template describes desired infrastructure in JSON. Bicep offers a declarative authoring language that compiles for ARM deployment.

Infrastructure as code records intended state so a change can be reviewed, versioned, and reproduced. Parameters separate environment inputs from resource logic. Dependencies help order related resources; outputs expose useful results. A valid local template is not proof that live authorization, region support, provider registration, or quota will permit deployment.

Stable resource names and scope let redeployment update intended resources rather than automatically create random duplicates. Deployment mode still matters: ordinary incremental omission does not delete every omitted resource. Manual changes can create **drift** between source and actual state. Investigate drift and agree which state is intended before reconciling it. Keep credentials out of source and validate results after deployment.

## Guided exercise

1. Inspect the definition and compile without creating Azure resources or generated source files:

   ```powershell
   Get-Content .\labs\18-arm-infrastructure\main.bicep
   az bicep build --file .\labs\18-arm-infrastructure\main.bicep --stdout
   if ($LASTEXITCODE -ne 0) { throw 'Bicep compilation failed' }
   ```

   Find `targetScope`, the three parameters, resource type/API version, ownership tags, and output. The expected network is `vnet-az900`, with `10.90.0.0/16` address space and `subnet-default` using `10.90.1.0/24`.

2. Set explicit inputs and review the wrapper's preview:

   ```powershell
   $SubscriptionId = Read-Host 'Lab subscription GUID'
   $Location = Read-Host 'Canonical Azure region'
   $RunId = Read-Host 'New lowercase run ID, 4–12 letters/digits'
   $p = @{SubscriptionId=$SubscriptionId; Location=$Location; RunId=$RunId}
   .\labs\18-arm-infrastructure\Preflight.ps1 @p
   .\labs\18-arm-infrastructure\Setup.ps1 @p
   ```

   Compilation is a local check. The wrapper's preview summarizes planned actions; it is not an ARM what-if result. ARM what-if is another way to inspect predicted deployment changes in an authorized deployment workflow.

3. Deploy and validate only after the preview matches your intended run:

   ```powershell
   .\labs\18-arm-infrastructure\Setup.ps1 @p -Execute
   .\labs\18-arm-infrastructure\Validate.ps1 @p
   $rg = "rg-az900-18-$RunId"
   az network vnet show --name vnet-az900 --resource-group $rg --subscription $SubscriptionId --query '{name:name,location:location,addressSpace:addressSpace,subnets:subnets[].{name:name,prefix:addressPrefix},tags:tags}' --output json
   if ($LASTEXITCODE -ne 0) { throw 'Network inspection failed' }
   az deployment group show --name "az900-18-$RunId" --resource-group $rg --subscription $SubscriptionId --query properties.provisioningState --output tsv
   if ($LASTEXITCODE -ne 0) { throw 'Deployment inspection failed' }
   ```

   Confirm `Succeeded`, exact network prefixes, and project/lab/run tags. The subnet does not have tags of its own; validation checks its parent, name, and properties.

4. Re-run `Setup.ps1 @p -Execute` with unchanged inputs, then validate. The guarded wrapper can reuse matching owned state. Explain why a changed run ID selects another resource-group name instead of claiming this one.

5. Break-fix on paper: someone changes the subnet prefix manually. Compare that hypothetical state with the source. Explain why the validator should report a mismatch and why silently adopting it would undermine reproducibility. Do not alter the live subnet to manufacture the error.

## Expected results

Local compilation succeeds. Live execution, when authorized by the learner, creates an owned group containing the declared VNet and subnet. Validation matches the definition, and repeating unchanged setup preserves the intended run. You can distinguish source compilation, preview, ARM deployment record, and actual resource state.

## Knowledge check

Complete the [30 original questions](questions.json). Aim for 24/30. Explain parameters, resource scope, API version, dependencies, outputs, and drift using this template.

## Troubleshooting

- **Bicep unavailable:** follow official tooling instructions, then retry compilation. No live deployment is required to identify a tool problem.
- **Provider not registered or insufficient permissions:** ask your lab-subscription administrator; the script does not silently alter providers or access.
- **Policy or lock blocks deployment:** use the error's scope and rule information to diagnose the condition rather than bypass it.
- **Tags, location, or network properties differ:** preserve the refusal. Use a fresh run ID or investigate your owned resource; do not adopt unrelated state.

## Cleanup

```powershell
.\labs\18-arm-infrastructure\Cleanup.ps1 @p
.\labs\18-arm-infrastructure\Cleanup.ps1 @p -Execute
az group exists --name $rg --subscription $SubscriptionId --output tsv
if ($LASTEXITCODE -ne 0) { throw 'Absence check failed' }
```

Expect `false`. The lifecycle wrapper checks ownership and expected inventory before removing the group and verifies absence. Deleting a deployment record alone would not be equivalent to deleting the deployed resources. Keep ignored local evidence private.

## References

- [Azure Resource Manager overview](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/overview)
- [Bicep overview](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview)
- [Bicep tooling](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)
- [ARM deployment modes](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deployment-modes)
- [Bicep what-if](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-what-if)
