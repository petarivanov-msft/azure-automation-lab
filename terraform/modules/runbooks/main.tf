locals {
  automation_account_id_parts = split("/", var.automation_account_id)
  subscription_id             = local.automation_account_id_parts[2]
  resource_group_from_id      = local.automation_account_id_parts[4]
  automation_account_from_id  = local.automation_account_id_parts[8]
}

# ============================================================================
# Runtime Environment: PowerShell 7.4
# Created via az rest (azapi has cred issues in some environments)
# ============================================================================

resource "null_resource" "ps74_runtime" {
  triggers = {
    automation_account_id = var.automation_account_id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      SUBSCRIPTION_ID='${local.subscription_id}'
      RESOURCE_GROUP='${local.resource_group_from_id}'
      AUTOMATION_ACCOUNT='${local.automation_account_from_id}'
      RUNTIME_NAME='PowerShell74'

      URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT/runtimeEnvironments/$RUNTIME_NAME?api-version=2023-05-15-preview"

      BODY=$(cat <<'JSON'
{
  "properties": {
    "runtime": {
      "language": "PowerShell",
      "version": "7.4"
    },
    "defaultPackages": {
      "Az": "12.3.0"
    },
    "description": "PowerShell 7.4 runtime environment"
  },
  "location": "${var.location}"
}
JSON
)

      echo "Creating PowerShell 7.4 runtime environment..."
      az rest --method PUT --uri "$URI" --body "$BODY" --headers "Content-Type=application/json" || true
      echo "PowerShell 7.4 runtime environment created (or already exists)."
    EOT
  }
}

# ============================================================================
# Runtime Environment: Python 3.10
# ============================================================================

resource "null_resource" "python310_runtime" {
  triggers = {
    automation_account_id = var.automation_account_id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      SUBSCRIPTION_ID='${local.subscription_id}'
      RESOURCE_GROUP='${local.resource_group_from_id}'
      AUTOMATION_ACCOUNT='${local.automation_account_from_id}'
      RUNTIME_NAME='Python310'

      URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT/runtimeEnvironments/$RUNTIME_NAME?api-version=2023-05-15-preview"

      BODY="{\"properties\":{\"runtime\":{\"language\":\"Python\",\"version\":\"3.10\"},\"description\":\"Python 3.10 runtime environment\"},\"location\":\"${var.location}\"}"

      echo "Creating Python 3.10 runtime environment..."
      az rest --method PUT --uri "$URI" --body "$BODY" --headers "Content-Type=application/json" || true
      echo "Python 3.10 runtime environment created (or already exists)."
    EOT
  }
}

# ============================================================================
# Runtime Environment packages for Python 3.10
# Uses azapi_resource for the packages sub-resource
# ============================================================================

resource "azapi_resource" "python310_pkg_azure_identity" {
  type      = "Microsoft.Automation/automationAccounts/runtimeEnvironments/packages@2023-05-15-preview"
  name      = "azure-identity"
  parent_id = "${var.automation_account_id}/runtimeEnvironments/Python310"

  body = jsonencode({
    properties = {
      contentLink = {
        uri = "https://files.pythonhosted.org/packages/source/a/azure-identity/azure_identity-1.17.1.tar.gz"
      }
    }
  })

  depends_on = [null_resource.python310_runtime]

  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "python310_pkg_azure_mgmt_resource" {
  type      = "Microsoft.Automation/automationAccounts/runtimeEnvironments/packages@2023-05-15-preview"
  name      = "azure-mgmt-resource"
  parent_id = "${var.automation_account_id}/runtimeEnvironments/Python310"

  body = jsonencode({
    properties = {
      contentLink = {
        uri = "https://files.pythonhosted.org/packages/source/a/azure-mgmt-resource/azure_mgmt_resource-23.1.1.tar.gz"
      }
    }
  })

  depends_on = [null_resource.python310_runtime]

  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "python310_pkg_azure_mgmt_compute" {
  type      = "Microsoft.Automation/automationAccounts/runtimeEnvironments/packages@2023-05-15-preview"
  name      = "azure-mgmt-compute"
  parent_id = "${var.automation_account_id}/runtimeEnvironments/Python310"

  body = jsonencode({
    properties = {
      contentLink = {
        uri = "https://files.pythonhosted.org/packages/source/a/azure-mgmt-compute/azure_mgmt_compute-30.6.0.tar.gz"
      }
    }
  })

  depends_on = [null_resource.python310_runtime]

  lifecycle {
    ignore_changes = [body]
  }
}

# ============================================================================
# PowerShell 5.1 Runbooks (standard azurerm - no runtime env needed)
# ============================================================================

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

# ============================================================================
# PowerShell 7.4 Runbooks
# azapi_resource with runtimeEnvironment property (2023-05-15-preview)
# Content is uploaded via az rest draft + publish pattern
# ============================================================================

resource "azapi_resource" "ps74_parallel_processing" {
  type      = "Microsoft.Automation/automationAccounts/runbooks@2023-05-15-preview"
  name      = "Demo-ParallelProcessing-PS74"
  parent_id = var.automation_account_id
  location  = var.location

  body = jsonencode({
    properties = {
      runbookType        = "PowerShell"
      runtimeEnvironment = "PowerShell74"
      logVerbose         = true
      logProgress        = true
      description        = "PowerShell 7.4 runbook - Demonstrates parallel processing with ForEach-Object -Parallel"
      draft              = {}
    }
    tags = var.tags
  })

  depends_on = [null_resource.ps74_runtime]

  lifecycle {
    ignore_changes = [body]
  }
}

resource "null_resource" "ps74_parallel_processing_content" {
  triggers = {
    content_hash = sha256(file("${path.module}/runbooks/Demo-ParallelProcessing-PS74.ps1"))
    runbook_id   = azapi_resource.ps74_parallel_processing.id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      SUBSCRIPTION_ID='${local.subscription_id}'
      RESOURCE_GROUP='${local.resource_group_from_id}'
      AUTOMATION_ACCOUNT='${local.automation_account_from_id}'
      RUNBOOK_NAME='Demo-ParallelProcessing-PS74'
      CONTENT=$(cat '${path.module}/runbooks/Demo-ParallelProcessing-PS74.ps1')

      DRAFT_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT/runbooks/$RUNBOOK_NAME/draft/content?api-version=2023-05-15-preview"
      PUBLISH_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT/runbooks/$RUNBOOK_NAME/publish?api-version=2023-05-15-preview"

      echo "Uploading content for $RUNBOOK_NAME..."
      echo "$CONTENT" | az rest --method PUT --uri "$DRAFT_URI" --body @- --headers "Content-Type=text/powershell"
      echo "Publishing $RUNBOOK_NAME..."
      az rest --method POST --uri "$PUBLISH_URI" --body "{}"
      echo "$RUNBOOK_NAME published."
    EOT
  }

  depends_on = [azapi_resource.ps74_parallel_processing]
}

resource "azapi_resource" "ps74_modern_features" {
  type      = "Microsoft.Automation/automationAccounts/runbooks@2023-05-15-preview"
  name      = "Demo-ModernFeatures-PS74"
  parent_id = var.automation_account_id
  location  = var.location

  body = jsonencode({
    properties = {
      runbookType        = "PowerShell"
      runtimeEnvironment = "PowerShell74"
      logVerbose         = true
      logProgress        = true
      description        = "PowerShell 7.4 runbook - Demonstrates ternary operators, null coalescing, and pipeline parallelization"
      draft              = {}
    }
    tags = var.tags
  })

  depends_on = [null_resource.ps74_runtime]

  lifecycle {
    ignore_changes = [body]
  }
}

resource "null_resource" "ps74_modern_features_content" {
  triggers = {
    content_hash = sha256(file("${path.module}/runbooks/Demo-ModernFeatures-PS74.ps1"))
    runbook_id   = azapi_resource.ps74_modern_features.id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      SUBSCRIPTION_ID='${local.subscription_id}'
      RESOURCE_GROUP='${local.resource_group_from_id}'
      AUTOMATION_ACCOUNT='${local.automation_account_from_id}'
      RUNBOOK_NAME='Demo-ModernFeatures-PS74'
      CONTENT=$(cat '${path.module}/runbooks/Demo-ModernFeatures-PS74.ps1')

      DRAFT_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT/runbooks/$RUNBOOK_NAME/draft/content?api-version=2023-05-15-preview"
      PUBLISH_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT/runbooks/$RUNBOOK_NAME/publish?api-version=2023-05-15-preview"

      echo "Uploading content for $RUNBOOK_NAME..."
      echo "$CONTENT" | az rest --method PUT --uri "$DRAFT_URI" --body @- --headers "Content-Type=text/powershell"
      echo "Publishing $RUNBOOK_NAME..."
      az rest --method POST --uri "$PUBLISH_URI" --body "{}"
      echo "$RUNBOOK_NAME published."
    EOT
  }

  depends_on = [azapi_resource.ps74_modern_features]
}

resource "azapi_resource" "ps74_resource_report" {
  type      = "Microsoft.Automation/automationAccounts/runbooks@2023-05-15-preview"
  name      = "Get-ResourceReport-PS74"
  parent_id = var.automation_account_id
  location  = var.location

  body = jsonencode({
    properties = {
      runbookType        = "PowerShell"
      runtimeEnvironment = "PowerShell74"
      logVerbose         = true
      logProgress        = true
      description        = "PowerShell 7.4 runbook - Generate comprehensive Azure resource report"
      draft              = {}
    }
    tags = var.tags
  })

  depends_on = [null_resource.ps74_runtime]

  lifecycle {
    ignore_changes = [body]
  }
}

resource "null_resource" "ps74_resource_report_content" {
  triggers = {
    content_hash = sha256(file("${path.module}/runbooks/Get-ResourceReport-PS74.ps1"))
    runbook_id   = azapi_resource.ps74_resource_report.id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      SUBSCRIPTION_ID='${local.subscription_id}'
      RESOURCE_GROUP='${local.resource_group_from_id}'
      AUTOMATION_ACCOUNT='${local.automation_account_from_id}'
      RUNBOOK_NAME='Get-ResourceReport-PS74'
      CONTENT=$(cat '${path.module}/runbooks/Get-ResourceReport-PS74.ps1')

      DRAFT_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT/runbooks/$RUNBOOK_NAME/draft/content?api-version=2023-05-15-preview"
      PUBLISH_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT/runbooks/$RUNBOOK_NAME/publish?api-version=2023-05-15-preview"

      echo "Uploading content for $RUNBOOK_NAME..."
      echo "$CONTENT" | az rest --method PUT --uri "$DRAFT_URI" --body @- --headers "Content-Type=text/powershell"
      echo "Publishing $RUNBOOK_NAME..."
      az rest --method POST --uri "$PUBLISH_URI" --body "{}"
      echo "$RUNBOOK_NAME published."
    EOT
  }

  depends_on = [azapi_resource.ps74_resource_report]
}

# ============================================================================
# Python 3.10 Runbooks
# azapi_resource with runtimeEnvironment = Python310
# ============================================================================

resource "azapi_resource" "python_hello_world" {
  type      = "Microsoft.Automation/automationAccounts/runbooks@2023-05-15-preview"
  name      = "Hello-World-Python"
  parent_id = var.automation_account_id
  location  = var.location

  body = jsonencode({
    properties = {
      runbookType        = "Python3"
      runtimeEnvironment = "Python310"
      logVerbose         = true
      logProgress        = true
      description        = "Python 3.10 runbook - Hello World example with Azure authentication"
      draft              = {}
    }
    tags = var.tags
  })

  depends_on = [null_resource.python310_runtime]

  lifecycle {
    ignore_changes = [body]
  }
}

resource "null_resource" "python_hello_world_content" {
  triggers = {
    content_hash = sha256(file("${path.module}/runbooks/hello_world.py"))
    runbook_id   = azapi_resource.python_hello_world.id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      SUBSCRIPTION_ID='${local.subscription_id}'
      RESOURCE_GROUP='${local.resource_group_from_id}'
      AUTOMATION_ACCOUNT='${local.automation_account_from_id}'
      RUNBOOK_NAME='Hello-World-Python'
      CONTENT=$(cat '${path.module}/runbooks/hello_world.py')

      DRAFT_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT/runbooks/$RUNBOOK_NAME/draft/content?api-version=2023-05-15-preview"
      PUBLISH_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT/runbooks/$RUNBOOK_NAME/publish?api-version=2023-05-15-preview"

      echo "Uploading content for $RUNBOOK_NAME..."
      echo "$CONTENT" | az rest --method PUT --uri "$DRAFT_URI" --body @- --headers "Content-Type=text/x-python"
      echo "Publishing $RUNBOOK_NAME..."
      az rest --method POST --uri "$PUBLISH_URI" --body "{}"
      echo "$RUNBOOK_NAME published."
    EOT
  }

  depends_on = [azapi_resource.python_hello_world]
}

resource "azapi_resource" "python_resource_inventory" {
  type      = "Microsoft.Automation/automationAccounts/runbooks@2023-05-15-preview"
  name      = "Get-ResourceInventory-Python"
  parent_id = var.automation_account_id
  location  = var.location

  body = jsonencode({
    properties = {
      runbookType        = "Python3"
      runtimeEnvironment = "Python310"
      logVerbose         = true
      logProgress        = true
      description        = "Python 3.10 runbook - Get Azure resource inventory using Azure SDK"
      draft              = {}
    }
    tags = var.tags
  })

  depends_on = [null_resource.python310_runtime]

  lifecycle {
    ignore_changes = [body]
  }
}

resource "null_resource" "python_resource_inventory_content" {
  triggers = {
    content_hash = sha256(file("${path.module}/runbooks/get_resource_inventory.py"))
    runbook_id   = azapi_resource.python_resource_inventory.id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      SUBSCRIPTION_ID='${local.subscription_id}'
      RESOURCE_GROUP='${local.resource_group_from_id}'
      AUTOMATION_ACCOUNT='${local.automation_account_from_id}'
      RUNBOOK_NAME='Get-ResourceInventory-Python'
      CONTENT=$(cat '${path.module}/runbooks/get_resource_inventory.py')

      DRAFT_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT/runbooks/$RUNBOOK_NAME/draft/content?api-version=2023-05-15-preview"
      PUBLISH_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT/runbooks/$RUNBOOK_NAME/publish?api-version=2023-05-15-preview"

      echo "Uploading content for $RUNBOOK_NAME..."
      echo "$CONTENT" | az rest --method PUT --uri "$DRAFT_URI" --body @- --headers "Content-Type=text/x-python"
      echo "Publishing $RUNBOOK_NAME..."
      az rest --method POST --uri "$PUBLISH_URI" --body "{}"
      echo "$RUNBOOK_NAME published."
    EOT
  }

  depends_on = [azapi_resource.python_resource_inventory]
}

resource "azapi_resource" "python_vm_management" {
  type      = "Microsoft.Automation/automationAccounts/runbooks@2023-05-15-preview"
  name      = "Manage-VMs-Python"
  parent_id = var.automation_account_id
  location  = var.location

  body = jsonencode({
    properties = {
      runbookType        = "Python3"
      runtimeEnvironment = "Python310"
      logVerbose         = true
      logProgress        = true
      description        = "Python 3.10 runbook - Start/Stop VMs using Azure SDK"
      draft              = {}
    }
    tags = var.tags
  })

  depends_on = [null_resource.python310_runtime]

  lifecycle {
    ignore_changes = [body]
  }
}

resource "null_resource" "python_vm_management_content" {
  triggers = {
    content_hash = sha256(file("${path.module}/runbooks/manage_vms.py"))
    runbook_id   = azapi_resource.python_vm_management.id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      SUBSCRIPTION_ID='${local.subscription_id}'
      RESOURCE_GROUP='${local.resource_group_from_id}'
      AUTOMATION_ACCOUNT='${local.automation_account_from_id}'
      RUNBOOK_NAME='Manage-VMs-Python'
      CONTENT=$(cat '${path.module}/runbooks/manage_vms.py')

      DRAFT_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT/runbooks/$RUNBOOK_NAME/draft/content?api-version=2023-05-15-preview"
      PUBLISH_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT/runbooks/$RUNBOOK_NAME/publish?api-version=2023-05-15-preview"

      echo "Uploading content for $RUNBOOK_NAME..."
      echo "$CONTENT" | az rest --method PUT --uri "$DRAFT_URI" --body @- --headers "Content-Type=text/x-python"
      echo "Publishing $RUNBOOK_NAME..."
      az rest --method POST --uri "$PUBLISH_URI" --body "{}"
      echo "$RUNBOOK_NAME published."
    EOT
  }

  depends_on = [azapi_resource.python_vm_management]
}

resource "azapi_resource" "python_tag_compliance" {
  type      = "Microsoft.Automation/automationAccounts/runbooks@2023-05-15-preview"
  name      = "Check-TagCompliance-Python"
  parent_id = var.automation_account_id
  location  = var.location

  body = jsonencode({
    properties = {
      runbookType        = "Python3"
      runtimeEnvironment = "Python310"
      logVerbose         = true
      logProgress        = true
      description        = "Python 3.10 runbook - Check resource tag compliance"
      draft              = {}
    }
    tags = var.tags
  })

  depends_on = [null_resource.python310_runtime]

  lifecycle {
    ignore_changes = [body]
  }
}

resource "null_resource" "python_tag_compliance_content" {
  triggers = {
    content_hash = sha256(file("${path.module}/runbooks/check_tag_compliance.py"))
    runbook_id   = azapi_resource.python_tag_compliance.id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      SUBSCRIPTION_ID='${local.subscription_id}'
      RESOURCE_GROUP='${local.resource_group_from_id}'
      AUTOMATION_ACCOUNT='${local.automation_account_from_id}'
      RUNBOOK_NAME='Check-TagCompliance-Python'
      CONTENT=$(cat '${path.module}/runbooks/check_tag_compliance.py')

      DRAFT_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT/runbooks/$RUNBOOK_NAME/draft/content?api-version=2023-05-15-preview"
      PUBLISH_URI="https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Automation/automationAccounts/$AUTOMATION_ACCOUNT/runbooks/$RUNBOOK_NAME/publish?api-version=2023-05-15-preview"

      echo "Uploading content for $RUNBOOK_NAME..."
      echo "$CONTENT" | az rest --method PUT --uri "$DRAFT_URI" --body @- --headers "Content-Type=text/x-python"
      echo "Publishing $RUNBOOK_NAME..."
      az rest --method POST --uri "$PUBLISH_URI" --body "{}"
      echo "$RUNBOOK_NAME published."
    EOT
  }

  depends_on = [azapi_resource.python_tag_compliance]
}
