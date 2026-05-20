output "windows_vm_id" {
  description = "ID of the Windows Hybrid Worker VM"
  value       = azurerm_windows_virtual_machine.windows.id
}

output "ubuntu_vm_id" {
  description = "ID of the Ubuntu Hybrid Worker VM"
  value       = azurerm_linux_virtual_machine.ubuntu.id
}

output "rhel_vm_id" {
  description = "ID of the RHEL Hybrid Worker VM"
  value       = azurerm_linux_virtual_machine.rhel.id
}

output "windows_worker_group_name" {
  description = "Name of the Windows Hybrid Worker Group"
  value       = azurerm_automation_hybrid_runbook_worker_group.windows.name
}

output "linux_worker_group_name" {
  description = "Name of the Linux Hybrid Worker Group"
  value       = azurerm_automation_hybrid_runbook_worker_group.linux.name
}

output "windows_vm_principal_id" {
  description = "Principal ID of the Windows VM managed identity"
  value       = azurerm_windows_virtual_machine.windows.identity[0].principal_id
}

output "ubuntu_vm_principal_id" {
  description = "Principal ID of the Ubuntu VM managed identity"
  value       = azurerm_linux_virtual_machine.ubuntu.identity[0].principal_id
}

output "rhel_vm_principal_id" {
  description = "Principal ID of the RHEL VM managed identity"
  value       = azurerm_linux_virtual_machine.rhel.identity[0].principal_id
}

output "deployment_instructions" {
  description = "Post-deployment instructions (cross-platform safe, replaces bash echo)"
  value       = <<-EOT
=== Hybrid Worker Deployment Complete ===
Automation Account : ${var.automation_account_name}
Resource Group     : ${var.resource_group_name}
Worker groups      : ${azurerm_automation_hybrid_runbook_worker_group.windows.name}, ${azurerm_automation_hybrid_runbook_worker_group.linux.name}

To run the connectivity test (Windows workers):
  az automation runbook start \
    --automation-account-name '${var.automation_account_name}' \
    --resource-group '${var.resource_group_name}' \
    --name 'Test-HybridWorker-ManagedIdentity' \
    --run-on '${azurerm_automation_hybrid_runbook_worker_group.windows.name}'

Note: Hybrid workers may take 5-10 minutes after VM extension installation
to fully register with the Automation Account before runbooks can execute.
  EOT
}

