# Lab 00 — Safe start and subscription readiness

**Duration:** 45 minutes · **Route:** read-only · **Verification:** offline-validated; author live testing not performed.

## Objectives

Establish a deliberate tool and subscription context, distinguish inspection from deployment, prepare a private learner configuration, and define what successful cleanup means. This setup lab supports every assessed objective but has no separate question bank.

## Prerequisites

Use PowerShell 7.4+, Azure CLI, an approved disposable subscription, and permission to inspect it. A subscription administrator must approve your live work. Read the [permissions matrix](../../docs/permissions.md) and [cost guidance](../../docs/cost-cleanup.md). Python is needed only for repository checks; Azure operations run through Azure CLI hosted in PowerShell.

## Scenario

You are joining a small team's Azure learning project. The team also has production subscriptions. Your first task is to prove that every later command will target the approved learning subscription. A valid exercise requires the right context and a cleanup plan before the first resource exists.

## Concept primer

Azure login establishes an identity; it does not grant every permission. The active subscription is a CLI convenience and can change between sessions. Explicit `--subscription` arguments make the intended scope visible. Tenant, subscription, resource group, and data-plane permissions are distinct. A role that creates a storage account may not read its blobs.

Read-only inspection can expose identifiers. Keep evidence private and redact it before sharing. Preview-first scripts show their intended ownership boundary without calling Azure. Executing a setup creates resources; executing cleanup deletes the owned resource group. Preview success does not prove that permissions, policy, or region availability will permit a live run.

## Guided exercise

From the repository root, inspect the tools:

```powershell
$PSVersionTable.PSVersion
az version
pwsh -NoProfile -File tools/Initialize-LabEnvironment.ps1
```

Expected observation: required tools are listed with readiness findings. Address missing tools through their official installation pages. The initializer does not authenticate or install them.

Authenticate yourself and choose your approved context:

```powershell
az login
az account list --query '[].{Name:name,Id:id,State:state}' -o table
$SubscriptionId = Read-Host 'Approved disposable subscription GUID'
az account set --subscription $SubscriptionId
az account show --query '{Name:name,Id:id,State:state}' -o json
az account list-locations --subscription $SubscriptionId --query '[].{Name:name,Display:displayName}' -o table
$Location = Read-Host 'Approved region name, for example an allowed region from the list'
$RunId = 'study001'
```

Compare the returned subscription ID with your approved ID. If it differs, stop and select the correct context. Regional presence in this list does not prove that a particular SKU or policy allows deployment there.

Create a private configuration and a private evidence directory:

```powershell
@{ subscriptionId = $SubscriptionId; location = $Location; runId = $RunId } |
  ConvertTo-Json | Set-Content learner.config.json
New-Item -ItemType Directory -Force evidence | Out-Null
git check-ignore learner.config.json evidence/hello.txt
```

Both paths should be ignored by Git. Run IDs must contain 4–12 lowercase letters/digits. They distinguish one lab run from another; they are not passwords.

Preview your first live exercise without deploying:

```powershell
./labs/06-azure-architecture/Setup.ps1 -SubscriptionId $SubscriptionId -Location $Location -RunId $RunId
```

Inspect the group name and tags. Do not add `-Execute` until you have read Lab 06 and can explain its cost, permissions, validation, and cleanup. This preview makes zero Azure calls.

## Expected results

- PowerShell and Azure CLI are ready, or specific missing prerequisites are reported.
- You can name the approved subscription and region without relying on implicit defaults.
- Private configuration and evidence paths are ignored by Git.
- The setup preview describes an owned group; no resources are created in this lab.

## Knowledge check

- Explain why a successful `az login` does not prove that blob upload is authorized.
- State the difference between inspecting a subscription and deploying in it.
- Name the positive cleanup observation: the owned resource group no longer exists.
- Explain why budget alerts are not a spending cap.
- Before continuing, confirm the tool, context, permission, ownership, cost, and cleanup decisions in your private notes.

## Troubleshooting

If `az account show` reports no subscription, review your signed-in identity and account access. If a later script reports a context mismatch, recheck the active subscription deliberately. Do not authenticate through somebody else's credentials. If Git does not ignore your configuration, verify that you are in this repository and that `.gitignore` is present.

A deliberate misconception exercise: imagine a session where the active subscription is production while the command text contains a lab group name. Explain why the familiar group name does not make the command safe, then add the explicit approved subscription to your example.

## Cleanup

This lab creates local configuration only. Keep it private or delete it when finished. There are no Azure resources to remove. Later live labs require validation, an inspected cleanup preview, explicit cleanup execution, and a final resource-group absence check.

## References

- [Sign in with Azure CLI](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli)
- [Manage Azure subscriptions with CLI](https://learn.microsoft.com/en-us/cli/azure/manage-azure-subscriptions-azure-cli)
- [Azure CLI installation](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Prerequisites](../../docs/prerequisites.md)
