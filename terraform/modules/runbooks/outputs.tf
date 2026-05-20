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
    parallel_processing = azapi_resource.ps74_parallel_processing.id
    modern_features     = azapi_resource.ps74_modern_features.id
    resource_report     = azapi_resource.ps74_resource_report.id
  }
}

# Python 3.10 Runbooks
output "python_runbook_ids" {
  description = "IDs of Python 3.10 runbooks"
  value = {
    hello_world        = azapi_resource.python_hello_world.id
    resource_inventory = azapi_resource.python_resource_inventory.id
    vm_management      = azapi_resource.python_vm_management.id
    tag_compliance     = azapi_resource.python_tag_compliance.id
  }
}

output "all_runbook_names" {
  description = "List of all runbook names"
  value = [
    azurerm_automation_runbook.ps51_get_azure_info.name,
    azurerm_automation_runbook.ps51_vm_inventory.name,
    azapi_resource.ps74_parallel_processing.name,
    azapi_resource.ps74_modern_features.name,
    azapi_resource.ps74_resource_report.name,
    azapi_resource.python_hello_world.name,
    azapi_resource.python_resource_inventory.name,
    azapi_resource.python_vm_management.name,
    azapi_resource.python_tag_compliance.name,
  ]
}
