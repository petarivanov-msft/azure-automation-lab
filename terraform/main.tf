data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "random_password" "vm_password" {
  length  = 16
  special = true
}

locals {
  vm_password = var.vm_admin_password != "" ? var.vm_admin_password : random_password.vm_password.result
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
  resource_group_id                = azurerm_resource_group.main.id
  subnet_id                        = module.network[0].subnet_id
  vm_admin_username                = var.vm_admin_username
  vm_admin_password                = local.vm_password
  run_test_runbook                 = var.run_test_runbook
  tags                             = var.tags
}

module "graph_api" {
  count = var.enable_graph_api ? 1 : 0

  source                        = "./modules/graph_api"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = var.location
  automation_account_name       = module.automation_account.automation_account_name
  automation_account_id         = module.automation_account.automation_account_id
  managed_identity_principal_id = module.automation_account.managed_identity_principal_id
  tags                          = var.tags
}
