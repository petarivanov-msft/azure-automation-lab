resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

locals {
  resource_group_name = "${var.resource_group_name}-${random_string.suffix.result}"
}

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

module "automation_account" {
  source                  = "./modules/automation_account"
  resource_group_name     = azurerm_resource_group.main.name
  location                = var.location
  automation_account_name = var.automation_account_name
  tags                    = var.tags
}

module "network" {
  count = var.enable_hybrid_workers ? 1 : 0

  source              = "./modules/network"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  allowed_source_ip   = var.allowed_source_ip
  tags                = var.tags
}

module "runbooks" {
  count = var.enable_runbooks ? 1 : 0

  source                  = "./modules/runbooks"
  resource_group_name     = azurerm_resource_group.main.name
  location                = var.location
  automation_account_id   = module.automation_account.automation_account_id
  automation_account_name = module.automation_account.automation_account_name
  tags                    = var.tags
}

module "hybrid_workers" {
  count = var.enable_hybrid_workers ? 1 : 0

  source                           = "./modules/hybrid_workers"
  resource_group_name              = azurerm_resource_group.main.name
  location                         = var.location
  automation_account_id            = module.automation_account.automation_account_id
  automation_account_name          = module.automation_account.automation_account_name
  automation_identity_principal_id = module.automation_account.managed_identity_principal_id
  hybrid_service_url               = module.automation_account.hybrid_service_url
  resource_group_id                = azurerm_resource_group.main.id
  subnet_id                        = module.network[0].subnet_id
  vm_admin_username                = var.vm_admin_username
  vm_admin_password                = var.vm_admin_password
  tags                             = var.tags
}

module "graph_api" {
  count = var.enable_graph_api ? 1 : 0

  source                        = "./modules/graph_api"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = var.location
  automation_account_name       = module.automation_account.automation_account_name
  managed_identity_principal_id = module.automation_account.managed_identity_principal_id
  skip_graph_permissions        = var.skip_graph_permissions
  tags                          = var.tags
}
