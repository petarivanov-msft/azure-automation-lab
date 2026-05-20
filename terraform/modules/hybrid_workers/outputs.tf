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
