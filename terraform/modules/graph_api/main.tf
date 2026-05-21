data "azuread_service_principal" "msgraph" {
  display_name = "Microsoft Graph"
}

resource "azurerm_automation_module" "graph_authentication" {
  count = var.skip_graph_permissions ? 0 : 1

  name                    = "Microsoft.Graph.Authentication"
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Authentication/2.11.1"
  }
}

resource "azurerm_automation_module" "graph_users" {
  count = var.skip_graph_permissions ? 0 : 1

  name                    = "Microsoft.Graph.Users"
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Users/2.11.1"
  }

  depends_on = [azurerm_automation_module.graph_authentication]
}

resource "azurerm_automation_module" "graph_groups" {
  count = var.skip_graph_permissions ? 0 : 1

  name                    = "Microsoft.Graph.Groups"
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Groups/2.11.1"
  }

  depends_on = [azurerm_automation_module.graph_authentication]
}

resource "azurerm_automation_module" "graph_applications" {
  count = var.skip_graph_permissions ? 0 : 1

  name                    = "Microsoft.Graph.Applications"
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Microsoft.Graph.Applications/2.11.1"
  }

  depends_on = [azurerm_automation_module.graph_authentication]
}

# App role GUIDs from: https://learn.microsoft.com/en-us/graph/permissions-reference
# These require Application Administrator or Privileged Role Administrator.
# Set skip_graph_permissions = true to deploy runbooks without granting permissions.
resource "azuread_app_role_assignment" "graph_users_read" {
  count = var.skip_graph_permissions ? 0 : 1

  app_role_id         = "df021288-bdef-4463-88db-98f22de89214" # User.Read.All
  principal_object_id = var.managed_identity_principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

resource "azuread_app_role_assignment" "graph_groups_read" {
  count = var.skip_graph_permissions ? 0 : 1

  app_role_id         = "5b567255-7703-4780-807c-7be8301ae99b" # Group.Read.All
  principal_object_id = var.managed_identity_principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

resource "azuread_app_role_assignment" "graph_applications_read" {
  count = var.skip_graph_permissions ? 0 : 1

  app_role_id         = "9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30" # Application.Read.All
  principal_object_id = var.managed_identity_principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

resource "azuread_app_role_assignment" "graph_directory_read" {
  count = var.skip_graph_permissions ? 0 : 1

  app_role_id         = "7ab1d382-f21e-4acd-a863-ba3e13f7da61" # Directory.Read.All
  principal_object_id = var.managed_identity_principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

# Graph API runbooks are always deployed (they're just PS scripts). Without
# the Graph modules and permissions they won't run successfully, but having
# them deployed means a user with admin rights can grant permissions later
# and immediately use the runbooks.
resource "azurerm_automation_runbook" "get_users" {
  name                    = "Get-UsersReport"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
  log_verbose             = "true"
  log_progress            = "true"
  runbook_type            = "PowerShell"

  content = file("${path.module}/runbooks/Get-UsersReport.ps1")
  tags    = var.tags
}

resource "azurerm_automation_runbook" "get_groups" {
  name                    = "Get-GroupsReport"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
  log_verbose             = "true"
  log_progress            = "true"
  runbook_type            = "PowerShell"

  content = file("${path.module}/runbooks/Get-GroupsReport.ps1")
  tags    = var.tags
}

resource "azurerm_automation_runbook" "get_applications" {
  name                    = "Get-ApplicationsReport"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
  log_verbose             = "true"
  log_progress            = "true"
  runbook_type            = "PowerShell"

  content = file("${path.module}/runbooks/Get-ApplicationsReport.ps1")
  tags    = var.tags
}
