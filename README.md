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

### Cloud Shell / Bash (Linux, macOS, WSL)

```bash
bash <(curl -s https://raw.githubusercontent.com/petarivanov-msft/azure-automation-lab/main/init-lab.sh)
```

> Use `bash <(curl ...)` — not `curl | bash`. The script needs interactive prompts.

### Windows / PowerShell (PowerShell 5.1, PowerShell 7+, Cloud Shell PowerShell)

```powershell
iex (iwr -useb https://raw.githubusercontent.com/petarivanov-msft/azure-automation-lab/main/init-lab.ps1).Content
```

Both scripts ask for resource names, region, NSG source IP, and which scenarios to deploy, then run `terraform apply` for you.

> **Security default:** The NSG ingress rules (RDP / WinRM / SSH) require an explicit source IP/CIDR. To open them to the public internet you must pass `allowed_source_ip = "*"` **and** `acknowledge_open_nsg = true` (or confirm the `YES` prompt in the bootstrap scripts). This avoids accidentally exposing the VMs.

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

# Copy the example and edit the values you care about.
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars (especially allowed_source_ip).

# Supply the VM password via an env var — do NOT put it in terraform.tfvars.
export TF_VAR_vm_admin_password='<a strong password>'

terraform init
terraform apply
```

Requirements: Terraform >= 1.9.0, Azure CLI (logged in via `az login`), git.

> **Supported environments:** Azure Cloud Shell (Bash *or* PowerShell), macOS/Linux terminal, Windows (PowerShell 5.1+ or PowerShell 7+), WSL.
> Terraform itself has no shell dependency — `init-lab.sh` and `init-lab.ps1` are convenience wrappers around the same `terraform apply`.

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

> **Note:** Hybrid worker registration is awaited automatically during `terraform apply` (a 3-minute `time_sleep` after the extension installs). No manual wait is needed before running the test runbook.

## Cleanup

```bash
cd terraform
terraform destroy

# Or use a helper:
bash   scripts/cleanup-lab.sh    # bash
pwsh   scripts/cleanup-lab.ps1   # PowerShell
```

## Repository Layout

```
azure-automation-lab/
├── terraform/                          Full modular lab
│   ├── main.tf, variables.tf, outputs.tf, provider.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── automation_account/
│       ├── hybrid_workers/
│       ├── runbooks/
│       ├── graph_api/
│       └── network/
├── scripts/
│   ├── cleanup-lab.sh
│   └── cleanup-lab.ps1
├── docs/
│   └── MIGRATION_GUIDE.md
├── init-lab.sh                          Cloud Shell / bash bootstrap
├── init-lab.ps1                         Windows / PowerShell bootstrap
└── .github/workflows/terraform-ci.yml
```

## Documentation

- [Migration Guide](docs/MIGRATION_GUIDE.md) — for users coming from older revisions

### Breaking changes in this revision

- **Per-VM `Contributor` role assignments removed.** The Automation Account managed identity still gets `Contributor` on the lab RG. The hybrid worker VMs now get `Automation Contributor` scoped only to the Automation Account (needed for HRW v2 extension registration) instead of the previous broad `Contributor` on the whole RG. If you've added runbooks that call IMDS on the VM directly and rely on the VM's own MI for resource management, add a targeted role assignment.
- **PS 7.4 runbook source files renamed** `*-PS72.ps1` → `*-PS74.ps1` (the Azure-side runbook names already had the `-PS74` suffix, so no portal-visible change). First `terraform apply` after pulling this revision will show in-place runbook updates.
- **VM admin password is no longer written to `terraform.tfvars`** by `init-lab.sh` / `init-lab.ps1`. It's set via the `TF_VAR_vm_admin_password` env var and stashed in a gitignored `.vm_admin.password` file. Re-export it before running `terraform apply` again.
- **NSG default tightened.** `allowed_source_ip = "*"` now fails validation unless `acknowledge_open_nsg = true` is also set.

## Resources

- [Azure Automation docs](https://learn.microsoft.com/azure/automation/)
- [Hybrid Worker docs](https://learn.microsoft.com/azure/automation/automation-hybrid-runbook-worker)
- [Terraform AzureRM provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

## License

MIT — see [LICENSE](LICENSE).
