# Permissions matrix

Permissions depend on assignment scope and subscription policy. Ask the subscription owner for the minimum required access rather than assigning yourself broad roles.

| Activity | Required capability | Notes |
| --- | --- | --- |
| Lab 00 and read-only exercises | Read subscription/resource metadata | Reader is sufficient for many management-plane queries; tenant and billing data may require separate access. |
| Labs 06, 08, 09, 10, 14, 18, 21 setup | Create/delete the specified resource groups and their resources | Contributor at subscription scope can create new groups; a group-scoped role needs the group pre-created and properly owned. Policy may still deny operations. |
| Lab 10 blob transfer | Storage data-plane access | Storage Blob Data Contributor at the account or container scope; Contributor alone does not grant Entra blob data access. Use `--auth-mode login`. |
| Lab 15 lock creation/removal | `Microsoft.Authorization/locks/write` and `/delete` | Owner or a custom role with these actions; Contributor cannot manage locks. |
| Policy, Entra, Defender, Purview, Arc lessons | Concept study or explicitly allowed read-only queries | No tenant-wide writes, paid-plan activation, or policy assignments are required. |
| Cost Management | Billing/cost read permissions for the relevant scope | Visibility varies by offer, billing account, and tenant settings. |

Role changes can take time to propagate. A failed request must be explained as a permission or policy failure, not bypassed by storage keys or unnecessary elevation.

[Azure built-in roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles) · [Blob authorization](https://learn.microsoft.com/en-us/azure/storage/blobs/authorize-access-azure-active-directory)
