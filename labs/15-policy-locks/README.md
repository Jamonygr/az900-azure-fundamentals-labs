# Lab 15 — Azure Policy and resource locks

**50 minutes · Owned group and delete lock · Offline-validated**

## Objectives

- **M06:** Distinguish Policy definitions, assignments, initiatives, and effects.
- **M07:** Explain management-lock levels, inheritance, and cleanup implications.

## Prerequisites

Complete [Lab 00](../00-safe-start/README.md) and [Lab 14](../14-cost-tags/README.md). Use PowerShell 7.4+, Azure CLI, and a subscription in which you may create/delete a group and manage its locks. Owner or equivalent explicit `Microsoft.Authorization/locks/*` permission is needed for lock management; Contributor alone does not supply every required lock action. Use a fresh run ID. This lesson inspects Policy definitions without assigning or remediating policies.

## Scenario

A project owner wants protection from accidental deletion and wants to understand how an approved-region rule could govern future resources. Create a delete lock on one owned empty group, inspect reusable Policy logic, and explain which control serves each requirement.

## Concept primer

[![Azure RBAC, Policy, locks, tags, Purview, and Cost Management answer different governance questions.](../../docs/assets/diagrams/governance-controls.svg)](../../docs/assets/diagrams/governance-controls.svg)

*Choose a control by its purpose and scope; a tag, role assignment, policy, and lock have different effects.*

A Policy **definition** holds a reusable rule and effect. An **assignment** applies a definition or **initiative**—a group of definitions—to a scope. Parameters adapt the rule. An `audit` effect reports matching noncompliance; `deny` can reject a prohibited request; effects such as `modify` and `deployIfNotExists` have additional behavior and remediation requirements. Evaluation and compliance reporting are not necessarily immediate. Listing a built-in definition does not enforce it. Policy governance complements RBAC authorization and does not itself grant the caller an Azure role.

Management locks restrict control-plane operations across applicable user roles. `CanNotDelete` blocks deletion while allowing authorized changes. `ReadOnly` restricts management modification as well as deletion and can block operations implemented with write/POST requests. Locks inherit from parent scopes; the most restrictive applicable lock matters. An Owner must remove an applicable lock before a protected deletion, if authorized to do so.

Locks are not data backups. They do not generally protect service data-plane content such as blob deletion. A locked child can block deleting its resource group. The lab cleanup removes only its own `az900-protection` lock with matching ownership notes; an unexpected or inherited external lock is a blocker, not an invitation to remove organizational controls.

## Guided exercise

1. Prepare explicit inputs and previews:

   ```powershell
   $SubscriptionId = Read-Host 'Lab subscription GUID'
   $Location = Read-Host 'Canonical Azure region'
   $RunId = Read-Host 'New lowercase run ID, 4–12 letters/digits'
   $p = @{SubscriptionId=$SubscriptionId; Location=$Location; RunId=$RunId}
   .\labs\15-policy-locks\Preflight.ps1 @p
   .\labs\15-policy-locks\Setup.ps1 @p
   ```

   Confirm the group is `rg-az900-15-$RunId` and the intended lock is `CanNotDelete`.

2. Execute the lab setup and inspect the result:

   ```powershell
   .\labs\15-policy-locks\Setup.ps1 @p -Execute
   .\labs\15-policy-locks\Validate.ps1 @p
   $rg = "rg-az900-15-$RunId"
   az lock list --resource-group $rg --subscription $SubscriptionId --query '[].{name:name,level:level,notes:notes}' --output json
   if ($LASTEXITCODE -ne 0) { throw 'Lock inspection failed' }
   ```

   Check the name, level, and project/lab/run ownership notes. Predict what a group-delete request would do. Do not test deletion with an unrestricted command; the owned cleanup sequence below demonstrates the correct ordering.

3. Inspect built-in policy definitions read-only:

   ```powershell
   $raw = az policy definition list --subscription $SubscriptionId --output json
   if ($LASTEXITCODE -ne 0) { throw 'Policy inspection failed' }
   $policies = $raw | ConvertFrom-Json
   $example = $policies | Where-Object policyType -eq 'BuiltIn' | Select-Object -First 1
   $example | Select-Object displayName,policyType
   $example.policyRule | ConvertTo-Json -Depth 20
   ```

   Identify the `if` condition and `then` effect. If the effect is parameterized, inspect its parameter definition. Explain that no assignment was created by listing the rule.

4. Write a synthetic approved-regions rule and choose `audit` for observation or `deny` for enforcement. Record the desired scope and any intended exclusions. Leave this as a design exercise; do not assign it.

5. Break-fix reasoning: a user has Owner but deletion is blocked; another has Contributor but cannot create the lock. Diagnose these as different control layers. Explain why a ReadOnly lock is not interchangeable with a Reader role.

## Expected results

One owned empty group has one `CanNotDelete` lock. Validation confirms expected ownership and configuration. You can explain definitions versus assignments, audit versus deny, the relevant lock permission, and why locks protect management actions rather than every stored record.

## Knowledge check

Complete the [30 original questions](questions.json). Aim for 24/30. For any rejected operation, identify whether permissions, a Policy rule, or a lock explains the failure.

## Troubleshooting

- **Lock creation fails:** ask the subscription administrator for the intended scoped permission; do not add broad roles yourself. Cleanup may still be needed for a partially created group.
- **External or inherited lock found:** stop and report its scope. Cleanup must not remove another team's protection.
- **Policy list denied:** use the official definition/effect documentation for concept study; do not change existing assignments.
- **Unexpected inventory or tags:** the lifecycle tool refuses ownership mismatches. Choose a new run rather than altering its checks.

## Cleanup

```powershell
.\labs\15-policy-locks\Cleanup.ps1 @p
.\labs\15-policy-locks\Cleanup.ps1 @p -Execute
az group exists --name $rg --subscription $SubscriptionId --output tsv
if ($LASTEXITCODE -ne 0) { throw 'Absence check failed' }
```

The wrapper checks the group, inventory, and lock ownership; removes its own lock; requests deletion; and verifies group absence. Expect `false`. There are no Policy assignments to remove. Keep local evidence private.

## References

- [Azure Policy overview](https://learn.microsoft.com/en-us/azure/governance/policy/overview)
- [Policy effects](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/effect-basics)
- [Scope in Azure Policy](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/scope)
- [Resource locks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/lock-resources)
