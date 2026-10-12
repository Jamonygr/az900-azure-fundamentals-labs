# Lab 13 — Zero Trust, defense in depth, and Defender

**40 minutes · Concept exercise · Offline-validated**

## Objectives

- **A25:** Apply the principles of Zero Trust.
- **A26:** Explain defense in depth using complementary controls.
- **A27:** Explain the role and limits of Microsoft Defender for Cloud.

## Prerequisites

Complete [Lab 12](../12-authentication-rbac/README.md). Use PowerShell 7.4+ for the local exercise. No Defender plan, agent, VM, or tenant policy is deployed; subscription security administrator access is unnecessary.

## Scenario

A company operates a public web app with customer records. Its staff believe the office network is trusted, one firewall is sufficient, and a favorable security score proves the application cannot be breached. Produce a small protection plan that corrects those assumptions.

## Concept primer

Zero Trust applies three principles: **verify explicitly**, **use least privilege**, and **assume breach**. Verify identities and relevant context instead of relying only on network location. Limit access to the task, scope, and needed duration. Plan containment and detection because an attacker may already have access. A user inside the office and a workload on a private network still need appropriate verification and authorization.

Defense in depth combines controls across physical facilities, identity, network, hosts, applications, and data. For example, provider datacenter protections, MFA, scoped roles, network filtering, guest-OS patching, input validation, encryption, monitoring, and tested recovery each address different risks. Several identical controls in one layer do not replace missing controls elsewhere. The provider and customer retain responsibilities appropriate to the chosen service model.

Microsoft Defender for Cloud supports security-posture assessment and workload protection across supported connected environments. Recommendations and posture scores help prioritize work; they do not guarantee prevention or certify every legal requirement. Capabilities and charges vary by plan. Review a finding, its scope, dependencies, and impact before changing a workload. This lab simulates findings rather than enabling security plans or collecting telemetry.

## Guided exercise

1. Create invented findings locally. This code has no Azure commands.

   ```powershell
   $findings = @(
     [pscustomobject]@{Finding='Staff share a deployment password'; Layer='Identity'}
     [pscustomobject]@{Finding='Database accepts unnecessary network sources'; Layer='Network'}
     [pscustomobject]@{Finding='Guest OS has missing security updates'; Layer='Host'}
     [pscustomobject]@{Finding='Sensitive records appear in debug output'; Layer='Application/data'}
     [pscustomobject]@{Finding='No alert or tested restore procedure'; Layer='Detection/recovery'}
   )
   $findings | Format-Table -Wrap
   ```

2. For each row, write one preventive control, one observation you would use to verify it, and the responsible team. Use individual identities and scoped permissions for the shared password; restrict unnecessary network paths; patch the guest OS; sanitize debug output; establish useful detection and tested recovery.

3. Map your plan to Zero Trust. Explicit verification covers sign-in and device context. Least privilege covers deployment rights and workload data access. Assuming breach supports segmentation, monitoring, and recovery. A control can contribute to more than one principle.

4. Break-fix on paper: suppose the firewall works but the deployment account is compromised. Identify two remaining layers that could limit harm. Do the same for an application bug that writes customer information to logs.

5. Read the Defender overview below. Write which invented findings a posture assessment could help surface, and why a recommendation still needs contextual review. Do not select any enable, upgrade, connect, or install action.

## Expected results

Your plan covers several layers and names verifiable outcomes rather than simply purchasing products. It protects management and data even when the public home page must remain reachable. You can distinguish a configuration recommendation from active threat detection and explain why a security score is one input to ongoing security work.

## Knowledge check

Complete the [30 original questions](questions.json). Aim for 24/30. For each wrong answer, identify which risk the proposed control addresses and which risk remains.

## Troubleshooting

- **“Private means trusted”:** an internal identity or system can be compromised. Describe the evidence required before granting access.
- **“Encryption prevents every breach”:** it protects particular data states; access, application, and monitoring controls remain useful.
- **“One Defender product solves everything”:** supported findings, connected scope, plan features, and customer remediation all matter.
- **Unfamiliar finding:** record what evidence would be needed; do not invent a guarantee or enable a paid plan to finish the exercise.

## Cleanup

No Azure configuration changes occur. Clear local variables with `Remove-Variable findings -ErrorAction SilentlyContinue`. Retain only invented examples. Existing Defender plans, tenant controls, and production infrastructure are outside this lab's cleanup scope.

## References

- [Zero Trust overview](https://learn.microsoft.com/en-us/security/zero-trust/zero-trust-overview)
- [Introduction to Azure security](https://learn.microsoft.com/en-us/azure/security/fundamentals/overview)
- [Defender for Cloud introduction](https://learn.microsoft.com/en-us/azure/defender-for-cloud/defender-for-cloud-introduction)
- [Zero Trust and Defender for Cloud](https://learn.microsoft.com/en-us/azure/defender-for-cloud/zero-trust)
