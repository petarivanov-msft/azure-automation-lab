# Migration Guide

The repo was restructured from separate per-scenario directories into a single unified Terraform setup.

## What Changed

**Old structure:** Four independent scenario directories (`01-graph-api-automation/`, `02-startstop-vms/`, etc.), each with its own Terraform state and PowerShell deploy script.

**New structure:** Single `terraform/` directory with feature flags, shared automation account and network, deployed via `init-lab.sh`.

## If You Have Old Deployments Running

They're independent — the new setup won't touch them. Destroy them manually if needed:

```bash
cd 01-graph-api-automation && terraform destroy -auto-approve
# repeat for other old scenario dirs
```

Old Terraform states can't be imported into the new structure — just redeploy.

## Feature Flag Mapping

| Old directory | New flag |
|--------------|----------|
| `01-graph-api-automation` | `enable_graph_api = true` |
| `02-startstop-vms` | `enable_runbooks = true` (Manage-VMs-Python) |
| `03-powershell74-runtime` | `enable_runbooks = true` |
| `04-hybrid-worker-setup` | `enable_hybrid_workers = true` |
