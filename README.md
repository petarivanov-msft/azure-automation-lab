# Azure Automation Lab

Terraform-based lab environment for Azure Automation. Covers hybrid workers (Windows / Linux / RHEL), runbooks in PowerShell 5.1, PowerShell 7.4, and Python 3.10, plus optional Graph API automation.

Built this as a hands-on reference for the kinds of setups I troubleshoot as an Azure TAM. Easiest way to spin it up is Cloud Shell.

> **Note:** This repo is the merged successor of
> [`azure-automation-scenarios`](https://github.com/petarivanov-msft/azure-automation-scenarios)
> and [`azure-hybrid-worker-lab`](https://github.com/petarivanov-msft/azure-hybrid-worker-lab).
> Both originals remain available but new work happens here.

## Two ways to deploy

| Path | Use when | Location |
|------|----------|----------|
| **Full modular lab** | You want runbooks (PS 5.1, PS 7.4, Python), Windows + Linux + RHEL hybrid workers, optional Graph API | [`terraform/`](./terraform) |
| **Minimal single-file example** | You want one Windows hybrid worker, top-to-bottom readable in one file, good for learning | [`examples/minimal-hybrid-worker/`](./examples/minimal-hybrid-worker) |

---

## Quick Start (Full Lab)

Open [Azure Cloud Shell](https://portal.azure.com) (Bash) and run:

```bash
bash <(curl -s https://raw.githubusercontent.com/petarivanov-msft/azure-automation-lab/main/init-lab.sh)
```

> Note: Use `bash <(curl ...)` — not `curl | bash`. The script needs interactive prompts.

The script will ask for resource names, region, and which scenarios to deploy, then runs `terraform apply` for you.

## What Gets Deployed (Full Lab)

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

## Manual Deployment (Full Lab)

```bash
git clone https://github.com/petarivanov-msft/azure-automation-lab.git
cd azure-automation-lab/terraform
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
terraform destroy

# Or use the helper:
bash scripts/cleanup-lab.sh
```

## Repository Layout

```
azure-automation-lab/
├── terraform/                          Full modular lab
│   ├── main.tf, variables.tf, outputs.tf, provider.tf
│   └── modules/
│       ├── automation_account/
│       ├── hybrid_workers/
│       ├── runbooks/
│       ├── graph_api/
│       └── network/
├── examples/
│   └── minimal-hybrid-worker/          Flat single-file quickstart
├── scripts/
│   └── cleanup-lab.sh
├── docs/
│   └── MIGRATION_GUIDE.md
├── init-lab.sh                          Cloud Shell bootstrap (full lab)
└── .github/workflows/terraform-ci.yml
```

## Documentation

- [Migration Guide](docs/MIGRATION_GUIDE.md) — for users coming from older revisions
- [Minimal example README](examples/minimal-hybrid-worker/README.md) — including troubleshooting notes for hybrid worker registration

## Resources

- [Azure Automation docs](https://learn.microsoft.com/azure/automation/)
- [Hybrid Worker docs](https://learn.microsoft.com/azure/automation/automation-hybrid-runbook-worker)
- [Terraform AzureRM provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

## License

MIT — see [LICENSE](LICENSE).
