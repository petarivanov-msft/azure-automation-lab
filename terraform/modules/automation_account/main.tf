resource "azurerm_automation_account" "main" {
  name                = var.automation_account_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_automation_module" "az_accounts" {
  name                    = "Az.Accounts"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Accounts/2.13.2"
  }
}

resource "azurerm_automation_module" "az_compute" {
  name                    = "Az.Compute"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Compute/5.7.0"
  }

  depends_on = [azurerm_automation_module.az_accounts]
}

resource "azurerm_automation_module" "az_resources" {
  name                    = "Az.Resources"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.main.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Resources/6.7.0"
  }

  depends_on = [azurerm_automation_module.az_accounts]
}
