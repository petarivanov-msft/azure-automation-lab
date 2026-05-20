locals {
  automation_account_id_parts = split("/", var.automation_account_id)
  subscription_id             = local.automation_account_id_parts[2]
  resource_group_from_id      = local.automation_account_id_parts[4]
  automation_account_from_id  = local.automation_account_id_parts[8]
}

# PS 7.4 runtime environment - azapi has credential issues so using az rest via CLI
resource "null_resource" "ps74_runtime" {
  triggers = {
    automation_account_id = var.automation_account_id
  }

  provisioner "local-exec" {
    interpreter = ["pwsh", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Stop'
      
      $subscriptionId = '${local.subscription_id}'
      $resourceGroup = '${local.resource_group_from_id}'
      $automationAccount = '${local.automation_account_from_id}'
      $runtimeName = 'PowerShell74'
      
      $uri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Automation/automationAccounts/$automationAccount/runtimeEnvironments/$runtimeName`?api-version=2023-05-15-preview"
      
      $body = @{
        properties = @{
          runtime = @{
            language = 'PowerShell'
            version = '7.4'
          }
          defaultPackages = @{
            Az = '12.3.0'
          }
          description = 'PowerShell 7.4 runtime environment'
        }
        location = '${var.location}'
      } | ConvertTo-Json -Depth 10
      
      Write-Host "Creating PowerShell 7.4 runtime environment..."
      az rest --method PUT --uri $uri --body $body --headers "Content-Type=application/json"
      Write-Host "PowerShell 7.4 runtime environment created successfully!"
    EOT
  }
}

resource "azurerm_automation_runbook" "ps51_get_azure_info" {
  name                    = "Get-AzureInfo-PS51"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
  log_verbose             = true
  log_progress            = true
  description             = "PowerShell 5.1 runbook - Get Azure subscription and resource information"
  runbook_type            = "PowerShell"

  content = file("${path.module}/runbooks/Get-AzureInfo-PS51.ps1")
  tags    = var.tags
}

resource "azurerm_automation_runbook" "ps51_vm_inventory" {
  name                    = "Get-VMInventory-PS51"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
  log_verbose             = true
  log_progress            = true
  description             = "PowerShell 5.1 runbook - Get VM inventory report"
  runbook_type            = "PowerShell"

  content = file("${path.module}/runbooks/Get-VMInventory-PS51.ps1")
  tags    = var.tags
}

resource "azurerm_automation_runbook" "ps74_parallel_processing" {
  name                    = "Demo-ParallelProcessing-PS74"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
  log_verbose             = true
  log_progress            = true
  description             = "PowerShell 7.4 runbook - Demonstrates parallel processing with ForEach-Object -Parallel"
  runbook_type            = "PowerShell"

  content = file("${path.module}/runbooks/Demo-ParallelProcessing-PS74.ps1")
  tags    = var.tags

  depends_on = [null_resource.ps74_runtime]
}

resource "azurerm_automation_runbook" "ps74_modern_features" {
  name                    = "Demo-ModernFeatures-PS74"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
  log_verbose             = true
  log_progress            = true
  description             = "PowerShell 7.4 runbook - Demonstrates ternary operators, null coalescing, and pipeline parallelization"
  runbook_type            = "PowerShell"

  content = file("${path.module}/runbooks/Demo-ModernFeatures-PS74.ps1")
  tags    = var.tags

  depends_on = [null_resource.ps74_runtime]
}

resource "azurerm_automation_runbook" "ps74_resource_report" {
  name                    = "Get-ResourceReport-PS74"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
  log_verbose             = true
  log_progress            = true
  description             = "PowerShell 7.4 runbook - Generate comprehensive Azure resource report"
  runbook_type            = "PowerShell"

  content = file("${path.module}/runbooks/Get-ResourceReport-PS74.ps1")
  tags    = var.tags

  depends_on = [null_resource.ps74_runtime]
}

resource "azurerm_automation_runbook" "python_hello_world" {
  name                    = "Hello-World-Python"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
  log_verbose             = true
  log_progress            = true
  description             = "Python 3.10 runbook - Hello World example with Azure authentication"
  runbook_type            = "Python3"

  content = file("${path.module}/runbooks/hello_world.py")
  tags    = var.tags
}

resource "azurerm_automation_runbook" "python_resource_inventory" {
  name                    = "Get-ResourceInventory-Python"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
  log_verbose             = true
  log_progress            = true
  description             = "Python 3.10 runbook - Get Azure resource inventory using Azure SDK"
  runbook_type            = "Python3"

  content = file("${path.module}/runbooks/get_resource_inventory.py")
  tags    = var.tags
}

resource "azurerm_automation_runbook" "python_vm_management" {
  name                    = "Manage-VMs-Python"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
  log_verbose             = true
  log_progress            = true
  description             = "Python 3.10 runbook - Start/Stop VMs using Azure SDK"
  runbook_type            = "Python3"

  content = file("${path.module}/runbooks/manage_vms.py")
  tags    = var.tags
}

resource "azurerm_automation_runbook" "python_tag_compliance" {
  name                    = "Check-TagCompliance-Python"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
  log_verbose             = true
  log_progress            = true
  description             = "Python 3.10 runbook - Check resource tag compliance"
  runbook_type            = "Python3"

  content = file("${path.module}/runbooks/check_tag_compliance.py")
  tags    = var.tags
}
