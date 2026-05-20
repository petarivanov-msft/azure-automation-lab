# ============================================================================
# Runbooks Module Outputs
# ============================================================================

# PowerShell 5.1 Runbooks
output "ps51_runbook_ids" {
  description = "IDs of PowerShell 5.1 runbooks"
  value = {
    get_azure_info = azurerm_automation_runbook.ps51_get_azure_info.id
    vm_inventory   = azurerm_automation_runbook.ps51_vm_inventory.id
  }
}

# PowerShell 7.4 Runbooks
output "ps74_runbook_ids" {
  description = "IDs of PowerShell 7.4 runbooks"
  value = {
    parallel_processing = azurerm_automation_runbook.ps74_parallel_processing.id
    modern_features     = azurerm_automation_runbook.ps74_modern_features.id
    resource_report     = azurerm_automation_runbook.ps74_resource_report.id
  }
}

# Python 3.10 Runbooks
output "python_runbook_ids" {
  description = "IDs of Python 3.10 runbooks"
  value = {
    hello_world        = azurerm_automation_runbook.python_hello_world.id
    resource_inventory = azurerm_automation_runbook.python_resource_inventory.id
    vm_management      = azurerm_automation_runbook.python_vm_management.id
    tag_compliance     = azurerm_automation_runbook.python_tag_compliance.id
  }
}

output "all_runbook_names" {
  description = "List of all runbook names"
  value = [
    azurerm_automation_runbook.ps51_get_azure_info.name,
    azurerm_automation_runbook.ps51_vm_inventory.name,
    azurerm_automation_runbook.ps74_parallel_processing.name,
    azurerm_automation_runbook.ps74_modern_features.name,
    azurerm_automation_runbook.ps74_resource_report.name,
    azurerm_automation_runbook.python_hello_world.name,
    azurerm_automation_runbook.python_resource_inventory.name,
    azurerm_automation_runbook.python_vm_management.name,
    azurerm_automation_runbook.python_tag_compliance.name
  ]
}
