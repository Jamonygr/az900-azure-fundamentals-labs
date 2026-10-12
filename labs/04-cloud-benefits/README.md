# Lab 04 — Cloud benefits and tradeoffs

40 minutes · Concept exercise · Offline-validated

## Objectives

- **C08:** Distinguish availability, scalability, and elasticity.
- **C09:** Explain reliability and performance/cost predictability.
- **C10:** Explain security and governance benefits.
- **C11:** Explain manageability of and in the cloud.

## Prerequisites

Complete Lab 03 and use PowerShell 7.4+. The capacity model is deliberately simplified and runs locally.

## Scenario

A school application is busy when term starts. Its designer says `Cloud means unlimited capacity and no outages`. Replace that claim with measurable requirements and an operational plan.

## Concept primer

High availability reduces service interruption through resilient design. Reliability is the system's ability to recover and keep meeting its intended function. Scaling up changes the capacity of an instance; scaling out adds instances. Elasticity adjusts capacity with demand, often automatically. A service must support and be configured for the chosen behavior; quotas, dependencies, and startup delays still matter.

Predictability comes from measurement, testing, capacity planning, and cost controls. Security tools help protect workloads, while governance establishes and evaluates organizational rules. Both still require customer decisions. Manageability **of** the cloud concerns operating services, such as monitoring and scaling. Manageability **in** the cloud concerns ways to manage them, such as APIs, a portal, and scripts. Avoid confusing a tool with a guaranteed outcome.

## Guided exercise

1. Simulate capacity planning:

```powershell
$demand = 40,180,70
$perInstance = 100
$demand | ForEach-Object {
    [pscustomobject]@{Requests=$_; Instances=[math]::Ceiling($_ / $perInstance)}
} | Format-Table
```

2. Expected instance counts are `1,2,1`. This models scale out and scale in. It does not test actual latency or perform Azure autoscaling.
3. Add a maximum of one instance using `[math]::Min(1, [math]::Ceiling($_ / $perInstance))`. The 180-request interval is now underprovisioned. Record the break-fix: raise a justified limit or reduce demand, then retest the real application.
4. Build a decision log with four entries: redundant instances for availability; restore testing for reliability; approved regions for governance; monitoring and a deployment script for manageability. Give each a verification method.
5. Describe one failure that two instances do not solve, such as a shared database outage. Verify that your plan considers dependencies instead of only frontend capacity.

## Expected results

You can distinguish related benefits and state the configuration or test needed to realize them. Your capacity calculation has an explicit limit and your reliability plan includes recovery.

## Knowledge check

Complete [the 30 questions](questions.json). For each wrong answer, identify which benefit it describes and why that differs from the requested outcome.

## Troubleshooting

An extra instance does not necessarily fix an inefficient query or shared bottleneck. An SLA is a service commitment with conditions, not a claim of zero downtime for your whole application. Autoscaling metrics and thresholds need testing.

## Cleanup

No Azure resources were created. Run `Remove-Variable demand,perInstance`; remove optional local logs when finished.

## References

- [Benefits of cloud services](https://learn.microsoft.com/en-us/training/modules/describe-benefits-use-cloud-services/)
- [Azure autoscale overview](https://learn.microsoft.com/en-us/azure/azure-monitor/autoscale/autoscale-overview)
- [Reliability design principles](https://learn.microsoft.com/en-us/azure/well-architected/reliability/principles)
