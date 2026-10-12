# Troubleshooting

| Observation | Investigation and next step |
| --- | --- |
| Readiness reports a missing tool | Install from its official source, reopen PowerShell, then rerun readiness. |
| Subscription context mismatch | Check `az account show`; explicitly select the approved subscription before retrying. |
| Region or SKU denied | Inspect the CLI error and subscription policy; choose an allowed region rather than changing policy. |
| Storage name unavailable | Choose a new run ID. Storage account names are globally unique. |
| Blob upload returns authorization failure | Verify Entra data-plane role, scope, propagation, and network rules. Keep `--auth-mode login`. |
| Lifecycle script refuses ownership | Inspect the group and children read-only. Do not retag or delete unrelated resources. |
| Cleanup reports an unexpected resource or lock | Identify its owner. Remove only your deliberately added resource through a reviewed process, then retry. |
| Activity Log is empty | Check time range, subscription, permissions, and recent management operations. Empty output is a valid observation. |
| Advisor has no recommendations | No recommendations does not imply perfect design; applicability depends on resource inventory and time. |
| Site progress disappears | Browser storage may be cleared, blocked, or isolated in private browsing. Progress is a local convenience. |

Retain redacted errors in ignored `evidence/`. Never include bearer tokens, storage keys, SAS URLs, or real customer data in an issue.
