# Azure Automation Scenarios Lab

Terraform-based lab environment for Azure Automation. Covers hybrid workers (Windows/Linux/RHEL), runbooks in PowerShell 5.1, PowerShell 7.4, and Python 3.10, plus optional Graph API automation.

Built this as a hands-on reference for the kinds of setups I troubleshoot as an Azure TAM. Easiest way to spin it up is Cloud Shell.

## Quick Start

Open [Azure Cloud Shell](https://portal.azure.com) (Bash) and run:

```bash
bash <(curl -s https://raw.githubusercontent.com/petarivanov-msft/azure-automation-scenarios/refs/heads/main/init-lab.sh)
```

> Note: Use `bash <(curl ...)` — not `curl | bash`. The script needs interactive prompts.

The script will ask for resource names, region, and which scenarios to deploy, then runs `terraform apply` for you.

## What Gets Deployed

**Always:**
- Resource group + Automation Account with system-assigned managed identity
- VNet + subnet for VMs

**Runbooks module** (`enable_runbooks = true`):
- `Get-AzureInfo-PS51` / `Get-VMInventory-PS51` — PS 5.1
- `Demo-ParallelProcessing-PS74` / `Demo-ModernFeatures-PS74` / `Get-ResourceReport-PS74` — PS 7.4
- `Hello-World-Python` / `Get-ResourceInventory-Python` / `Manage-VMs-Python` / `Check-TagCompliance-Python` — Python 3.10

**Hybrid Workers module** (`enable_hybrid_workers = true`):
- 3 VMs: Windows Server 2022, Ubuntu 22.04, RHEL 9
- Each registered as a hybrid worker with system-assigned MI
- PowerShell Az modules pre-installed

**Graph API module** (`enable_graph_api = false` by default):
- Requires Application Administrator or Privileged Role Administrator in Entra ID
- Adds `Get-UsersReport`, `Get-GroupsReport`, `Get-ApplicationsReport` runbooks

## Manual Deployment

If you prefer running locally:

```bash
git clone https://github.com/petarivanov-msft/azure-automation-scenarios.git
cd azure-automation-scenarios/terraform
terraform init

cat > terraform.tfvars <<EOF
resource_group_name     = "rg-automation-lab"
location                = "uksouth"
automation_account_name = "auto-lab-12345"
vm_admin_username       = "azureadmin"
vm_admin_password       = "<generate-a-strong-password>"
enable_runbooks         = true
enable_hybrid_workers   = true
enable_graph_api        = false
EOF

terraform apply
```

Requirements: Terraform >= 1.3.0, Azure CLI, Bash

## Running Runbooks

```bash
# From terraform output
AA=$(terraform output -raw automation_account_name)
RG=$(terraform output -raw resource_group_name)

# Run a runbook in the cloud
az automation runbook start --automation-account-name $AA --resource-group $RG --name "Get-VMInventory-PS51"

# Run on a hybrid worker
az automation runbook start --automation-account-name $AA --resource-group $RG --name "Get-AzureInfo-PS51" --run-on "hybrid-workers-windows"
```

## Cleanup

```bash
cd terraform
terraform destroy -auto-approve
```

## Known Gotchas

- Graph API permissions can take 5-10 minutes to propagate after deployment
- Module imports in the Automation Account also take a few minutes — check status under Modules before running runbooks
- Hybrid worker extension installation runs as part of `terraform apply` but the worker won't be ready for jobs immediately — give it a few minutes
- Python runbooks need `azure-identity` and `azure-mgmt-*` packages installed in the Automation Account

## Permissions

| What | Required |
|------|---------|
| Core lab + runbooks | Contributor on the resource group |
| Hybrid workers | Contributor on the resource group |
| Graph API module | Application Administrator or Privileged Role Administrator in Entra ID |

---

Terraform >= 1.3.0 · azurerm ~> 3.0 · azuread ~> 2.0 · azapi ~> 1.0
