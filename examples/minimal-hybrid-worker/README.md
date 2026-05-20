# Minimal Hybrid Worker Example

Flat, single-file Terraform config that deploys a complete Azure Automation Hybrid Worker lab. Originally `azure-hybrid-worker-lab` — kept here as a minimal, top-to-bottom readable reference.

If you want the full modular lab (multiple runbooks, Linux/RHEL workers, Graph API), use the root `terraform/` directory instead. This example is for when you just need **one Windows hybrid worker** and want to see every resource in one file.

## What it deploys

- Windows Server 2022 VM with system-assigned managed identity
- Azure Automation Account with system-assigned managed identity
- Hybrid Worker Group + VM registration
- Az.Accounts and Az.Compute modules on both VM and Automation Account
- Test runbook that authenticates via managed identity and lists VMs
- Contributor role assignments for both identities
- Full networking stack (VNet, subnet, NSG, public IP)

Total: ~22 resources, ~7-10 min to deploy.

## Prerequisites

- Azure CLI authenticated (`az login`)
- Terraform >= 1.0
- Active Azure subscription

## Deploy

```bash
git clone https://github.com/petarivanov-msft/azure-automation-lab.git
cd azure-automation-lab/examples/minimal-hybrid-worker
terraform init
terraform apply -auto-approve
```

From Azure Cloud Shell, you can also use `./deploy-cloudshell.sh` which adds some prompts and shows outputs nicely.

## Configuration

Edit `variables.tf` to change region, VM size, prefix, etc. Defaults are fine for a lab.

To skip the auto runbook test:
```hcl
run_test_runbook = false
```

## Cost

~$38/month if the VM runs 24/7 (Standard_B2s + public IP + storage). Run `terraform destroy -auto-approve` when done.

## Notes

The tricky part was getting the `AutomationHybridServiceUrl` — Terraform doesn't expose it directly, so I'm using an external data source with `az rest` to pull it from the ARM API. Also had to make sure the VM is registered in the worker group *before* installing the extension, otherwise you get a `machineId not associated` error.

## Troubleshooting

- **Module not found in runbook**: `Az.Accounts` import can take a few minutes. Check `provisioningState` in the portal.
- **Managed identity auth fails**: Role propagation delay. Wait a minute and re-run.
- **Extension times out**: Normal — it downloads the agent, configures the service, validates connectivity. ~3 min is expected.

## Cleanup

```bash
terraform destroy -auto-approve
```

## Resources

- [Azure Automation Hybrid Worker docs](https://learn.microsoft.com/azure/automation/automation-hybrid-runbook-worker)
- [Terraform AzureRM provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
