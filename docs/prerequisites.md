# Prerequisites

You need PowerShell 7.4 or later, Azure CLI, an approved disposable Azure subscription, and permission to manage the lab resource groups. Install tools through their official installers; the readiness script does not install, authenticate, or register providers automatically.

Run `pwsh -NoProfile -File tools/Initialize-LabEnvironment.ps1` from the repository root. Check Azure CLI with `az version` and your context with `az account show`. Authenticate yourself using `az login`; then use `az account set --subscription <your-subscription-id>` to select the intended subscription.

Lab 18 additionally needs the Bicep CLI through `az bicep`. Lab 10 uses Azure CLI for its required transfer; AzCopy is optional enrichment. Python 3.11+ is needed only for repository checks and local site preview.

Copy `learner.config.example.json` to ignored `learner.config.json` and replace the placeholder subscription and region. Choose a run ID of 4–12 lowercase letters/digits. Live script calls still require explicit arguments: configuration is a private convenience, never implicit execution authorization.

Review the [permissions matrix](permissions.md) before a lab. Free/student subscriptions may restrict regions, SKUs, or role assignment privileges. An approved region can be found with `az account list-locations --subscription <your-subscription-id> -o table`. Subscription policy may further restrict that list.

Live scripts target the public Azure cloud. Sovereign clouds are covered conceptually; their management endpoints and service availability differ. Do not use a production subscription. Complete [Lab 00](../labs/00-safe-start/README.md) before provisioning resources.

[Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) · [Install PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell) · [Bicep installation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)
