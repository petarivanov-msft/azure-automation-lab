output "runbook_names" {
  description = "Names of Graph API runbooks"
  value = [
    azurerm_automation_runbook.get_users.name,
    azurerm_automation_runbook.get_groups.name,
    azurerm_automation_runbook.get_applications.name
  ]
}

output "module_names" {
  description = "Names of installed Graph modules"
  value = [
    azurerm_automation_module.graph_authentication.name,
    azurerm_automation_module.graph_users.name,
    azurerm_automation_module.graph_groups.name,
    azurerm_automation_module.graph_applications.name
  ]
}

output "permissions_granted" {
  description = "Graph API permissions granted to managed identity"
  value = [
    "User.Read.All",
    "Group.Read.All",
    "Application.Read.All",
    "Directory.Read.All"
  ]
}
