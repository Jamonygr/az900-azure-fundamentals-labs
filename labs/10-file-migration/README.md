# Lab 10 — File transfer and migration decisions

50 minutes · Live: one small authenticated blob · Offline-validated; Azure execution is learner-run

## Objectives

- **A18:** Select AzCopy, Storage Explorer, or File Sync for file movement.
- **A19:** Select Azure Migrate or Data Box for migration.

## Prerequisites

Complete Lab 09. Use PowerShell 7.4+ and authenticated Azure CLI with management permissions **and** `Storage Blob Data Contributor` data permissions at the lab account or an appropriate parent scope. Ask an authorized administrator to grant the least required approved scope if needed; these scripts do not assign roles. Allow propagation time. A management Contributor role alone does not grant Entra blob-data access. AzCopy is optional and is not required for this exercise.

## Scenario

A nonprofit must upload one document now, retain a Windows file-server cache, assess legacy servers, and transfer a large archive over a slow connection. Use a tiny harmless fixture to practice upload/download, then choose the tools for the larger jobs.

## Concept primer

AzCopy is a command-line data-transfer tool suited to scripted/bulk transfers. Storage Explorer supplies a graphical storage-management interface. Azure File Sync synchronizes Azure Files with supported Windows Server endpoints and can tier cold files to the cloud while retaining local access. It is not a generic replacement for server assessment.

Azure Migrate helps discover, assess, and migrate supported workloads to Azure. Data Box uses a physical device for supported offline data-transfer scenarios when network transfer is impractical. Uploading a file is not a complete migration: dependencies, compatibility, cutover, permissions, and validation still need planning. Select using source/destination, data size, bandwidth, ongoing synchronization, and workload type.

## Guided exercise

Run from this lab directory. Set your own values and inspect the preview before execution:

```powershell
$SubscriptionId = 'YOUR-SUBSCRIPTION-GUID'
$Location = 'YOUR-APPROVED-REGION'
$RunId = 'study01'
$ResourceGroup = "rg-az900-10-$RunId"
$StorageAccount = "staz90010$RunId"
./Preflight.ps1 -SubscriptionId $SubscriptionId -Location $Location -RunId $RunId
./Setup.ps1 -SubscriptionId $SubscriptionId -Location $Location -RunId $RunId
./Setup.ps1 -SubscriptionId $SubscriptionId -Location $Location -RunId $RunId -Execute -AcknowledgeCost
```

Create a harmless local file in an ignored location; no secrets or personal data:

```powershell
$Scratch = Join-Path ([IO.Path]::GetTempPath()) "az900-10-$RunId"
New-Item -ItemType Directory -Path $Scratch -Force | Out-Null
$Fixture = Join-Path $Scratch 'hello.txt'
$Downloaded = Join-Path $Scratch 'downloaded.txt'
'Hello AZ-900' | Set-Content -LiteralPath $Fixture -Encoding utf8
az storage container show --name practice --account-name $StorageAccount --auth-mode login --subscription $SubscriptionId -o json
if ($LASTEXITCODE -ne 0) { throw 'Setup created practice; resolve approved data access before uploading.' }
az storage blob upload --account-name $StorageAccount --container-name practice --name hello.txt --file $Fixture --auth-mode login --overwrite false --subscription $SubscriptionId -o json
if ($LASTEXITCODE -ne 0) { throw 'Upload failed; inspect the error before continuing.' }
az storage blob download --account-name $StorageAccount --container-name practice --name hello.txt --file $Downloaded --auth-mode login --subscription $SubscriptionId -o json
if ($LASTEXITCODE -ne 0) { throw 'Download failed.' }
(Get-FileHash -LiteralPath $Fixture).Hash -eq (Get-FileHash -LiteralPath $Downloaded).Hash
./Validate.ps1 -SubscriptionId $SubscriptionId -Location $Location -RunId $RunId
```

1. Expect hash comparison `True`. A successful request alone does not prove identical content.
2. Break-fix safely: request blob `missing.txt` with `az storage blob show` and the same account/container/auth/subscription arguments. Expect `BlobNotFound`; restore `hello.txt`. Do not solve an authorization error by enabling anonymous access.
3. Sketch the optional AzCopy equivalent: authenticate with `azcopy login`, then copy the local fixture to the account's `practice/hello.txt` HTTPS URL using existing legitimate data permissions. Do not generate/paste account keys or SAS secrets. This is a comparison, not a required extra upload.
4. Choose File Sync for the retained Windows cache, Azure Migrate for server assessment, and Data Box for a sufficiently large supported transfer with inadequate bandwidth. Explain why one tool does not fit all three.

## Expected results

One authenticated test blob exists; uploaded/downloaded hashes match. You can distinguish one-time copy, ongoing sync, workload migration, and physical data transfer.

## Knowledge check

Complete [the 30 questions](questions.json). State the evidence needed before migration cutover and why management permission does not imply data permission.

## Troubleshooting

For `AuthorizationPermissionMismatch`, verify identity, approved data-role scope, and propagation with the administrator. For network denial, use the organization's permitted access path. A repeated upload with `--overwrite false` should refuse overwriting an existing blob; inspect it or choose a fresh owned run rather than overwriting silently. Files marked online-only by File Sync need connectivity to recall their content.

## Cleanup

```powershell
./Cleanup.ps1 -SubscriptionId $SubscriptionId -Location $Location -RunId $RunId
./Cleanup.ps1 -SubscriptionId $SubscriptionId -Location $Location -RunId $RunId -Execute
az group exists --name $ResourceGroup --subscription $SubscriptionId -o tsv
```

Confirm `false`. Delete only `hello.txt` and `downloaded.txt` from the known `$Scratch` directory when no longer needed; keep useful hash evidence locally. The lifecycle cleanup removes the owned account, container, and blob together.

## References

- [AzCopy](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10)
- [Storage Explorer](https://learn.microsoft.com/en-us/azure/storage/storage-explorer/vs-azure-tools-storage-manage-with-storage-explorer)
- [Azure File Sync](https://learn.microsoft.com/en-us/azure/storage/file-sync/file-sync-introduction)
- [Azure Migrate](https://learn.microsoft.com/en-us/azure/migrate/migrate-services-overview)
- [Data Box](https://learn.microsoft.com/en-us/azure/databox/data-box-overview)
- [Authorize blob access with Azure CLI](https://learn.microsoft.com/en-us/azure/storage/blobs/authorize-data-operations-cli)
