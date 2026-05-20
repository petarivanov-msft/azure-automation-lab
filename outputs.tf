output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "vm_name" {
  value = azurerm_windows_virtual_machine.vm.name
}

output "vm_public_ip" {
  value = azurerm_public_ip.pip.ip_address
}

output "vm_admin_username" {
  value = var.admin_username
}

output "vm_admin_password" {
  value     = random_password.vm_password.result
  sensitive = true
}

output "vm_principal_id" {
  value = azurerm_windows_virtual_machine.vm.identity[0].principal_id
}

output "automation_account_name" {
  value = azurerm_automation_account.automation.name
}

output "automation_account_id" {
  value = azurerm_automation_account.automation.id
}

output "automation_hybrid_service_url" {
  description = "The hybrid service URL — useful for troubleshooting worker registration"
  value       = data.external.automation_hybrid_url.result.url
}

output "automation_principal_id" {
  value = azurerm_automation_account.automation.identity[0].principal_id
}

output "hybrid_worker_group_name" {
  value = azurerm_automation_hybrid_runbook_worker_group.worker_group.name
}

output "runbook_name" {
  value = azurerm_automation_runbook.test_hybrid_worker.name
}

output "azure_portal_link" {
  value = "https://portal.azure.com/#@/resource${azurerm_resource_group.rg.id}"
}

output "runbook_link" {
  value = "https://portal.azure.com/#@/resource${azurerm_automation_runbook.test_hybrid_worker.id}"
}
