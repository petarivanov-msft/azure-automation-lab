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

# The built-in PowerShell-5.1 and PowerShell-7.2 runtime environments already
# include Az.Accounts, Az.Compute, and Az.Resources. Explicit module imports
# are NOT needed — they add 5-10 minutes of deploy time downloading from
# PowerShell Gallery and frequently hit transient CDN failures.
#
# If you need a specific newer version of an Az module, uncomment and pin:
#
# resource "azurerm_automation_module" "az_accounts" {
#   name                    = "Az.Accounts"
#   resource_group_name     = var.resource_group_name
#   automation_account_name = azurerm_automation_account.main.name
#   module_link {
#     uri = "https://www.powershellgallery.com/api/v2/package/Az.Accounts/2.13.2"
#   }
# }
