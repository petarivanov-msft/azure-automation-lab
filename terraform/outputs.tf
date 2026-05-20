output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "resource_group_portal_url" {
  value = "https://portal.azure.com/#@/resource${azurerm_resource_group.main.id}"
}

output "location" {
  value = var.location
}

output "automation_account_name" {
  value = module.automation_account.automation_account_name
}

output "automation_account_portal_url" {
  value = "https://portal.azure.com/#@/resource${module.automation_account.automation_account_id}"
}

output "automation_identity_principal_id" {
  value = module.automation_account.managed_identity_principal_id
}

output "runbook_names" {
  value = var.enable_runbooks ? module.runbooks[0].all_runbook_names : []
}

output "hybrid_worker_windows_vm" {
  value = var.enable_hybrid_workers ? module.hybrid_workers[0].windows_vm_id : null
}

output "hybrid_worker_ubuntu_vm" {
  value = var.enable_hybrid_workers ? module.hybrid_workers[0].ubuntu_vm_id : null
}

output "hybrid_worker_rhel_vm" {
  value = var.enable_hybrid_workers ? module.hybrid_workers[0].rhel_vm_id : null
}

output "hybrid_worker_groups" {
  value = var.enable_hybrid_workers ? {
    windows = module.hybrid_workers[0].windows_worker_group_name
    linux   = module.hybrid_workers[0].linux_worker_group_name
  } : {}
}

output "graph_api_runbooks" {
  value = var.enable_graph_api ? module.graph_api[0].runbook_names : []
}

output "vm_admin_username" {
  value = var.vm_admin_username
}

output "vm_admin_password" {
  description = "retrieve with: terraform output -raw vm_admin_password"
  value       = local.vm_password
  sensitive   = true
}

output "deployment_summary" {
  value = {
    runbooks_enabled       = var.enable_runbooks
    hybrid_workers_enabled = var.enable_hybrid_workers
    graph_api_enabled      = var.enable_graph_api
    vms_created            = var.enable_hybrid_workers ? 3 : 0
    vm_types               = var.enable_hybrid_workers ? ["Windows Server 2022", "Ubuntu 22.04", "RHEL 9"] : []
  }
}
