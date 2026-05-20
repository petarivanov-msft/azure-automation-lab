output "resource_group_name" {
  description = "Name of the deployed resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_portal_url" {
  description = "Azure portal URL for the resource group"
  value       = "https://portal.azure.com/#@/resource${azurerm_resource_group.main.id}"
}

output "location" {
  description = "Azure region of the deployment"
  value       = var.location
}

output "automation_account_name" {
  description = "Name of the Automation Account"
  value       = module.automation_account.automation_account_name
}

output "automation_account_portal_url" {
  description = "Azure portal URL for the Automation Account"
  value       = "https://portal.azure.com/#@/resource${module.automation_account.automation_account_id}"
}

output "automation_identity_principal_id" {
  description = "Principal ID of the Automation Account system-assigned managed identity"
  value       = module.automation_account.managed_identity_principal_id
}

output "runbook_names" {
  description = "List of deployed runbook names"
  value       = var.enable_runbooks ? module.runbooks[0].all_runbook_names : []
}

output "hybrid_worker_windows_vm" {
  description = "Resource ID of the Windows hybrid worker VM"
  value       = var.enable_hybrid_workers ? module.hybrid_workers[0].windows_vm_id : null
}

output "hybrid_worker_ubuntu_vm" {
  description = "Resource ID of the Ubuntu hybrid worker VM"
  value       = var.enable_hybrid_workers ? module.hybrid_workers[0].ubuntu_vm_id : null
}

output "hybrid_worker_rhel_vm" {
  description = "Resource ID of the RHEL hybrid worker VM"
  value       = var.enable_hybrid_workers ? module.hybrid_workers[0].rhel_vm_id : null
}

output "hybrid_worker_groups" {
  description = "Map of hybrid worker group names (windows, linux)"
  value = var.enable_hybrid_workers ? {
    windows = module.hybrid_workers[0].windows_worker_group_name
    linux   = module.hybrid_workers[0].linux_worker_group_name
  } : {}
}

output "graph_api_runbooks" {
  description = "List of Graph API runbook names (empty when module disabled)"
  value       = var.enable_graph_api ? module.graph_api[0].runbook_names : []
}

output "vm_admin_username" {
  description = "Admin username for the hybrid worker VMs"
  value       = var.vm_admin_username
}

output "vm_admin_password" {
  description = "Admin password for the hybrid worker VMs (retrieve with: terraform output -raw vm_admin_password)"
  value       = var.vm_admin_password
  sensitive   = true
}

output "deployment_summary" {
  description = "Summary of what was deployed"
  value = {
    runbooks_enabled       = var.enable_runbooks
    hybrid_workers_enabled = var.enable_hybrid_workers
    graph_api_enabled      = var.enable_graph_api
    vms_created            = var.enable_hybrid_workers ? 3 : 0
    vm_types               = var.enable_hybrid_workers ? ["Windows Server 2022", "Ubuntu 22.04", "RHEL 9"] : []
  }
}
