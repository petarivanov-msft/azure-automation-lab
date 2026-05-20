# Azure Automation Lab

Terraform-based lab environment for Azure Automation. Covers hybrid workers (Windows / Linux / RHEL), runbooks in PowerShell 5.1, PowerShell 7.4, and Python 3.10, plus optional Graph API automation.

Built this as a hands-on reference for the kinds of setups I troubleshoot as an Azure TAM. Easiest way to spin it up is Cloud Shell.

> **Note:** This repo is the merged successor of
> [`azure-automation-scenarios`](https://github.com/petarivanov-msft/azure-automation-scenarios)
> and [`azure-hybrid-worker-lab`](https://github.com/petarivanov-msft/azure-hybrid-worker-lab).
> Both originals remain available but new work happens here.

## Minimal deployment

There is only one deployment path: the full modular lab in [`terraform/`](./terraform).

For a "minimal" deployment (just hybrid workers, no runbooks, no Graph API), use these variable values:

```hcl
enable_hybrid_workers = true
enable_runbooks       = false
enable_graph_api      = false
```

---

## Quick Start

Open [Azure Cloud Shell](https://portal.azure.com) (Bash) and run:

```bash
bash <(curl -s https://raw.githubusercontent.com/petarivanov-msft/azure-automation-lab/main/init-lab.sh)
```

> Note: Use `bash <(curl ...)` — not `curl | bash`. The script needs interactive prompts.

The script will ask for resource names, region, and which scenarios to deploy, then runs `terraform apply` for you.

## What Gets Deployed

**Always:**
- Resource group + Automation Account with system-assigned managed identity
- VNet + subnet for VMs

**Runbooks module** (`enable_runbooks = true`):
- `Get-AzureInfo-PS51` / `Get-VMInventory-PS51` — PS 5.1
- `Demo-ParallelProcessing-PS74` / `Demo-ModernFeatures-PS74` / `Get-ResourceReport-PS74` — PS 7.4 (custom runtime environment `PS74`)
- `Hello-World-Python` / `Get-ResourceInventory-Python` / `Manage-VMs-Python` / `Check-TagCompliance-Python` — Python 3.10 (custom runtime environment `Python310`)

> **Runtime Environments:** Azure Automation system-generated envs cover PS-5.1, PS-7.1, PS-7.2, Python-2.7, Python-3.8, Python-3.10.
> PS-7.4 has **no** system-generated env — a custom `PS74` env is created by Terraform.

**Hybrid Workers module** (`enable_hybrid_workers = true`):
- 3 VMs: Windows Server 2022, Ubuntu 22.04, RHEL 9
- Each registered as a hybrid worker with system-assigned MI
- PowerShell Az modules pre-installed
- `Test-HybridWorker-ManagedIdentity` runbook created and published for manual validation

**Graph API module** (`enable_graph_api = false` by default):
- Requires Application Administrator or Privileged Role Administrator in Entra ID
- Adds `Get-UsersReport`, `Get-GroupsReport`, `Get-ApplicationsReport` runbooks

## Manual Deployment

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

Requirements: Terraform >= 1.3.0, Azure CLI

> **Supported deployment environments:** Azure Cloud Shell (Bash), macOS/Linux terminal, Windows (PowerShell or CMD), WSL.
> No Bash dependency — all local-exec blocks have been eliminated. The Terraform provider handles everything natively.

## Running Runbooks

```bash
# From terraform output
AA=$(terraform output -raw automation_account_name)
RG=$(terraform output -raw resource_group_name)

# Run a PS 5.1 runbook in the cloud
az automation runbook start --automation-account-name $AA --resource-group $RG --name "Get-VMInventory-PS51"

# Run the hybrid worker connectivity test on Windows workers
az automation runbook start --automation-account-name $AA --resource-group $RG \
  --name "Test-HybridWorker-ManagedIdentity" --run-on "hybrid-workers-windows"

# Run the hybrid worker connectivity test on Linux workers
az automation runbook start --automation-account-name $AA --resource-group $RG \
  --name "Test-HybridWorker-ManagedIdentity" --run-on "hybrid-workers-linux"
```

> **Note:** After `terraform apply`, allow 5–10 minutes for hybrid workers to fully register before running runbooks on them.

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
├── scripts/
│   └── cleanup-lab.sh
├── docs/
│   └── MIGRATION_GUIDE.md
├── init-lab.sh                          Cloud Shell bootstrap
└── .github/workflows/terraform-ci.yml
```

## Documentation

- [Migration Guide](docs/MIGRATION_GUIDE.md) — for users coming from older revisions

## Resources

- [Azure Automation docs](https://learn.microsoft.com/azure/automation/)
- [Hybrid Worker docs](https://learn.microsoft.com/azure/automation/automation-hybrid-runbook-worker)
- [Terraform AzureRM provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

## License

MIT — see [LICENSE](LICENSE).
