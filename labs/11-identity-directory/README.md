# Lab 11 — Directories and external identities

**35 minutes · Concept exercise · Offline-validated**

## Objectives

- **A20:** Compare Microsoft Entra ID with Microsoft Entra Domain Services.
- **A22:** Select an identity approach for business guests and application customers.

## Prerequisites

Complete [Lab 00](../00-safe-start/README.md). Use PowerShell 7.4+ and Azure CLI with an authenticated account. The subscription command below is read-only. Directory administration privileges and a managed domain are unnecessary.

## Scenario

A small company has three projects: employees signing in to a cloud expense app, an old application that requires LDAP and Kerberos, and an external design agency collaborating on a project. A fourth project offers a shopping app to consumers. Your job is to match each audience and protocol requirement to an identity service before anyone deploys it.

## Concept primer

Microsoft Entra ID is the cloud directory for users, applications, and other identities. An Entra **tenant** is a dedicated directory instance. A subscription is an Azure resource and billing boundary associated with a directory; several subscriptions can use the same tenant. Directory sign-in and permission to manage subscription resources are separate decisions.

Microsoft Entra Domain Services supplies managed traditional-domain capabilities such as domain join, Group Policy, LDAP, and Kerberos/NTLM. It can support applications that cannot readily adopt modern authentication. Microsoft maintains the managed domain controllers. Identity information normally flows from Entra ID into the managed domain; deploying it is an operational and potentially chargeable decision, not a prerequisite for ordinary cloud-app sign-in.

Microsoft Entra External ID covers people outside the organization. **B2B collaboration** lets business guests collaborate in a workforce tenant using supported existing identities. An **external tenant** targets customer-facing application identity experiences. An invitation establishes an identity relationship; it does not grant every application or Azure permission. Review access scope and remove access when the task ends.

## Guided exercise

1. Identify the subscription's directory association. Substitute your actual subscription GUID; keep the identifier and output out of public evidence.

   ```powershell
   $SubscriptionId = Read-Host 'Enter your lab subscription GUID'
   az account show --subscription $SubscriptionId --query '{subscription:id,tenant:tenantId,state:state}' --output json
   if ($LASTEXITCODE -ne 0) { throw 'Subscription inspection failed' }
   ```

   Record whether the state is `Enabled` and which field represents the directory. A tenant ID is an identifier, not proof that you can administer the tenant.

2. Build a local decision table using invented requirements:

   ```powershell
   $cases = @(
     [pscustomobject]@{Audience='Employees'; Need='Modern cloud app sign-in'}
     [pscustomobject]@{Audience='Employees'; Need='Legacy LDAP and Kerberos'}
     [pscustomobject]@{Audience='Partner designers'; Need='One enterprise project app'}
     [pscustomobject]@{Audience='Retail customers'; Need='Customer app sign-up and sign-in'}
   )
   $cases | Format-Table
   ```

   For each row, write the service, the reason, and one permission boundary in local notes. Choose Entra ID, Domain Services, workforce B2B collaboration, or a customer external-tenant design as appropriate.

3. Break the design on paper: suppose the partner invitation automatically grants subscription Owner. Explain why that exceeds the collaboration task. Replace it with access to the agreed app and a planned review date.

4. Verify your reasoning: could the old application use Entra ID alone without changing its LDAP requirement? Does successful guest sign-in prove access to a report? Explain both answers without creating users or domains.

## Expected results

The four rows map respectively to Entra ID, Entra Domain Services, B2B collaboration, and customer identity in an external tenant. The first two choices differ because of protocol requirements. Partner and customer scenarios differ in audience and application design. You can identify `tenantId` in account output and distinguish it from subscription ID.

## Knowledge check

Complete the [30 original questions](questions.json) in the site's assessment. Aim for 24/30, then explain every missed answer using this primer. Verify you can distinguish a directory, an Azure resource container, a managed domain, and external-app access without relying on product-name keywords alone.

## Troubleshooting

- **Subscription not found:** compare the GUID with `az account list --output table`; authenticate to the directory that contains your permitted subscription.
- **No directory administration permission:** continue the synthetic exercise. This lesson requires no directory writes.
- **“A tenant is a region”:** a tenant is an identity boundary; regions describe infrastructure geography.
- **“Guest means administrator”:** invitation and authorization are separate. List the task before selecting permissions.

## Cleanup

No Azure resources or identities are created. Clear local variables with `Remove-Variable cases,SubscriptionId -ErrorAction SilentlyContinue` and retain only invented, non-sensitive decision notes. Do not create a managed domain or invite users to complete this lab.

## References

- [Compare Microsoft directory-based services](https://learn.microsoft.com/en-us/entra/identity/domain-services/compare-identity-solutions)
- [Microsoft Entra Domain Services overview](https://learn.microsoft.com/en-us/entra/identity/domain-services/overview)
- [Microsoft Entra External ID overview](https://learn.microsoft.com/en-us/entra/external-id/external-identities-overview)
- [AZ-900 study guide](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-900)
