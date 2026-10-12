# AZ-900 Azure Fundamentals Labs

[![Quality and Pages](https://github.com/Jamonygr/az900-azure-fundamentals-labs/actions/workflows/quality-pages.yml/badge.svg)](https://github.com/Jamonygr/az900-azure-fundamentals-labs/actions/workflows/quality-pages.yml)

A beginner-friendly, command-first learning environment for Microsoft Azure Fundamentals: **22 labs, 600 original practice questions, and all 57 current objective bullets mapped to exercises**.

**[Open the searchable learning site](https://jamonygr.github.io/az900-azure-fundamentals-labs/)** · [Lab catalog](docs/catalog.md) · [Objective map](docs/objective-map.md) · [Study pathways](docs/study-plan.md)

The curriculum follows the [English AZ-900 objectives effective July 20, 2026](https://learn.microsoft.com/en-us/credentials/certifications/resources/study-guides/az-900). This independent project is inspired by the structure of [our AZ-104 learning repository](https://github.com/Jamonygr/az104-azure-administrator-labs); the lessons, assessments, and tooling here are written for AZ-900.

[![Learning path from safe setup through three AZ-900 domains to the integrated capstone](docs/assets/diagrams/learning-path.svg)](docs/assets/diagrams/learning-path.svg)

Open any learning diagram to view it at full size. Diagrams illustrate concepts; each lesson identifies exactly what its exercise creates or inspects.

## Start here

1. Read [prerequisites](docs/prerequisites.md) and [cost and cleanup guidance](docs/cost-cleanup.md).
2. Complete [Lab 00](labs/00-safe-start/README.md), using PowerShell 7.4+ and Azure CLI with your approved disposable subscription.
3. Work through Labs 01–20. Concept exercises use local reasoning; the hands-on curriculum requires Azure.
4. Use the [practice assessments](docs/assessments.md) to revisit weak topics, then finish [Lab 21](labs/21-integrated-capstone/README.md).

## What you get

| Domain | Labs | Questions | Official exam weight |
| --- | --- | --- | --- |
| Cloud concepts | 01–05 | 150 | 25–30% |
| Azure architecture and services | 06–13 | 240 | 35–40% |
| Azure management and governance | 14–20 | 210 | 30–35% |
| Setup and capstone | 00, 21 | Completion checklists | — |

Each lesson explains a scenario, objectives, prerequisites, expected observations, verification, troubleshooting, cleanup, and Microsoft references. Resource-creating labs include preview-first lifecycle scripts. Lab metadata and assessment JSON are validated automatically. Site assessments give explanations and remediation links; progress stays in your browser.

## Safe execution

Supply your subscription, region, and a unique run ID explicitly. Setup and cleanup scripts preview by default. `-Execute` permits changes; storage and capstone setup also require `-AcknowledgeCost`. Read the preview before executing. See the [permissions matrix](docs/permissions.md).

Azure resources can incur charges. Budget alerts do not stop spending. Cleanup is complete only after the resource group is absent. Keep personal configuration and evidence outside Git; ignored paths are supplied.

## Verification status

The repository is **offline-validated**: content contracts, script syntax and mocked safety behavior, Bicep compilation, and documentation builds are checked. Azure deployments have **not** been live-tested by the repository author. Every lab retains that distinction; learners verify actual results in their own environments.

## Build locally

```powershell
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements-dev.txt
.venv/Scripts/python tools/validate_repository.py
pwsh -NoProfile -File tests/Test-LabRuntime.ps1
.venv/Scripts/python tools/build_docs.py
.venv/Scripts/python -m mkdocs serve --strict
```

Use Python 3.11 or later. Quality and Pages run together in GitHub Actions; site deployment follows successful checks on `main`.

## Contributing and license

Read [contributing guidance](CONTRIBUTING.md) and [security reporting](SECURITY.md). Code and documentation are available under the [MIT license](LICENSE). Questions are original learning material and are not Microsoft exam items or a guarantee of exam results.
