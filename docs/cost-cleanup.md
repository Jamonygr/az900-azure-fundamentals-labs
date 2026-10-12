# Cost and cleanup

The required live activities create resource groups, virtual networks, and small Standard_LRS storage accounts. Storage capacity and operations can incur charges. Prices depend on region, billing agreement, operation type, and retained data. Review the [Azure pricing calculator](https://azure.microsoft.com/en-us/pricing/calculator/) before storage and capstone execution; do not rely on a hard-coded price.

## Before execution

- Confirm subscription, region, permissions, and resource provider readiness.
- Choose a fresh run ID. Preview setup, inspect the resource names, then explicitly execute.
- Keep blob payloads tiny. Do not enable versioning, backups, paid Defender plans, gateways, private endpoints, Purview accounts, or monitoring ingestion for these lessons.
- Review Cost Management. A budget sends alerts; it does not automatically cap or stop spending.

## Ownership boundaries

Each lab creates `rg-az900-{lab-id}-{run-id}` with project, lab, and run ownership tags. Scripts refuse mismatched tags or unexpected resources. Never remove a refusal by retagging somebody else's resources. Investigate through read-only commands and choose a fresh run ID.

## Finish each live lab

1. Run `Validate.ps1` and retain redacted observations privately.
2. Preview `Cleanup.ps1` with the same subscription, location, and run ID.
3. Execute cleanup when finished. Only the owned named lab lock can be removed automatically.
4. Confirm `az group exists --name <owned-group> --subscription <your-subscription-id>` returns `false`.
5. Check Cost Management later for billed usage already incurred; deleting resources does not erase prior charges.

If cleanup fails, treat the lab as unfinished. Review active resources and locks in the exact group. Do not expand deletion to other groups or subscription-wide resources. Storage recovery settings may retain deleted data according to the service's configuration; inspect those settings before an exercise and record any retention.

## Evidence handling

`evidence/` and `learner.config.json` are ignored by Git. Redact identifiers, usernames, IP addresses, tokens, resource IDs, and payload data before sharing. An ignore rule is not a security boundary: review `git diff --cached` before every commit.

[Cost Management budgets](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets) · [Resource locks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/lock-resources)
