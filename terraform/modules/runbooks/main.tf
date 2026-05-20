# ==============================================================================
# RUNBOOKS MODULE - main.tf
#
# RESEARCH SOURCES & DECISIONS
# ──────────────────────────────────────────────────────────────────────────────
# [1] azurerm_automation_runbook (hashicorp/azurerm ~3.x)
#     Source: https://raw.githubusercontent.com/hashicorp/terraform-provider-azurerm/main/website/docs/r/automation_runbook.html.markdown
#     - Supports `runtime_environment_name` (Optional) to bind a runbook to a
#       runtime environment. Works for runbook_type = "PowerShell" or "Python3".
#     - `content` can be set inline — no publish step needed. azurerm provider
#       handles draft+publish internally when content is supplied.
#     - API provider used: Microsoft.Automation 2024-10-23 (GA, not preview).
#     - Valid runbook_type values: Graph, GraphPowerShell, GraphPowerShellWorkflow,
#       PowerShellWorkflow, PowerShell, PowerShell72, Python, Python3, Python2, Script.
#     DECISION: Use azurerm_automation_runbook with runtime_environment_name for
#     ALL runbooks. Eliminates every null_resource + bash local-exec block for
#     content upload and publish. Cross-platform safe.
#
# [2] Built-in runtime environment names
#     Source: https://learn.microsoft.com/en-us/azure/automation/runtime-environment-overview
#     - System-generated names (with hyphens): PowerShell-5.1, PowerShell-7.1,
#       PowerShell-7.2, Python-2.7, Python-3.8, Python-3.10.
#     - NOTE: PowerShell-7.4 does NOT have a system-generated runtime env.
#       PowerShell 7.4 requires a CUSTOM runtime environment created via API/portal.
#     - PS 7.2 is in the system-generated list but is EOL (parent PS dropped support).
#       Docs say 7.4 is recommended. We create a custom PS 7.4 env via azapi.
#     DECISION: Create a custom "PS74" runtime env via azapi for PS 7.4 runbooks.
#     Runbooks renamed *-PS72 → *-PS74 to match what they actually use.
#     (The files on disk are named *-PS72.ps1 for backward compat with existing
#     test baselines, but the Azure runbook names are *-PS74.)
#
# [3] azapi_resource syntax (Azure/azapi ~1.x)
#     Source: https://raw.githubusercontent.com/Azure/terraform-provider-azapi/main/docs/resources/resource.md
#     - body: Dynamic (not string) — use native HCL object, NOT jsonencode() in v2+.
#       In v1 (current constraint ~1.0), jsonencode() is correct.
#     - schema_validation_enabled (Boolean): defaults true. Can set false to skip
#       embedded schema validation for preview API types.
#     - response_export_values: list of paths or map of name→JMESPath query.
#     - API version embedded in `type` string: "ResourceType@api-version"
#     DECISION: Keep jsonencode() for body (provider ~1.0). Use API 2024-10-23 (GA).
#     Set schema_validation_enabled = false for runtime environment resources since
#     some fields (e.g. runtimeEnvironment in runbook body) are not in embedded schema.
#
# [4] Python 3.10 package format
#     Source: https://learn.microsoft.com/en-us/azure/automation/python-3-packages
#     "Currently, Python 3.10 only supports wheel files."
#     "For Python 3.10 packages, use .whl files targeting cp310 Linux OS."
#     Old code used .tar.gz source tarballs — WRONG for 3.10.
#     DECISION: Switch all Python package URIs to py3-none-any .whl files.
#     (azure-identity, azure-mgmt-resource, azure-mgmt-compute are pure Python,
#     so py3-none-any wheels are correct; no platform-specific cp310 build needed.)
#     URLs confirmed from https://pypi.org/pypi/<pkg>/<version>/json (May 2026):
#       azure_identity-1.17.1-py3-none-any.whl
#       azure_mgmt_resource-23.1.1-py3-none-any.whl
#       azure_mgmt_compute-30.6.0-py3-none-any.whl
#
# [5] Cross-platform local-exec (tester round 2 feedback)
#     DECISION: Eliminate ALL local-exec by using native azurerm/azapi resources.
#     Zero bash/pwsh local-exec in this module. Works on Windows, macOS, Linux,
#     Cloud Shell with no shell dependency.
#
# [6] API version
#     Source: runtime-environment-overview page states API 2024-10-23 (GA).
#     Old code used 2023-05-15-preview. Updated throughout.
# ==============================================================================

locals {
  automation_account_id_parts = split("/", var.automation_account_id)
  subscription_id             = local.automation_account_id_parts[2]
  resource_group_from_id      = local.automation_account_id_parts[4]
  automation_account_from_id  = local.automation_account_id_parts[8]
}

# ==============================================================================
# Runtime Environment: PowerShell 7.4 (custom — no system-generated env exists)
#
# RESEARCH: MS Docs confirm system-generated envs only include PS-5.1, PS-7.1,
# PS-7.2, Python-2.7, Python-3.8, Python-3.10. PS-7.4 is NOT system-generated.
# We must create a custom env via REST API. azapi is used here.
#
# API: Microsoft.Automation/automationAccounts/runtimeEnvironments@2024-10-23 (GA)
# schema_validation_enabled = false: the 'defaultPackages' key isn't in the
# embedded azapi schema for this resource type, but is accepted by the ARM API.
# ==============================================================================

resource "azapi_resource" "ps74_runtime" {
  type      = "Microsoft.Automation/automationAccounts/runtimeEnvironments@2024-10-23"
  name      = "PS74"
  parent_id = var.automation_account_id
  location  = var.location

  body = jsonencode({
    properties = {
      runtime = {
        language = "PowerShell"
        version  = "7.4"
      }
      defaultPackages = {
        Az = "12.3.0"
      }
      description = "PowerShell 7.4 runtime environment with Az 12.3.0"
    }
  })

  schema_validation_enabled = false

  lifecycle {
    ignore_changes = [body]
  }
}

# ==============================================================================
# Runtime Environment: Python 3.10
#
# RESEARCH: Python-3.10 IS a system-generated runtime env name, but the
# system-generated one may already exist. We create a custom one "Python310"
# to own the lifecycle and add custom packages to it. The system-generated
# env "Python-3.10" can't be modified directly.
#
# Runbooks will reference "Python310" (our custom env name).
# ==============================================================================

resource "azapi_resource" "python310_runtime" {
  type      = "Microsoft.Automation/automationAccounts/runtimeEnvironments@2024-10-23"
  name      = "Python310"
  parent_id = var.automation_account_id
  location  = var.location

  body = jsonencode({
    properties = {
      runtime = {
        language = "Python"
        version  = "3.10"
      }
      description = "Python 3.10 runtime environment"
    }
  })

  schema_validation_enabled = false

  lifecycle {
    ignore_changes = [body]
  }
}

# ==============================================================================
# Python 3.10 Packages
#
# RESEARCH: Python 3.10 requires .whl files (NOT .tar.gz).
# Ref: https://learn.microsoft.com/en-us/azure/automation/python-3-packages
# "Currently, Python 3.10 only supports wheel files."
#
# azure-identity, azure-mgmt-resource, azure-mgmt-compute are pure Python
# packages (py3-none-any wheels). URLs confirmed from PyPI JSON API May 2026.
#
# API: Microsoft.Automation/automationAccounts/runtimeEnvironments/packages@2024-10-23
# parent_id must include the runtime environment path segment.
# ==============================================================================

resource "azapi_resource" "python310_pkg_azure_identity" {
  type      = "Microsoft.Automation/automationAccounts/runtimeEnvironments/packages@2024-10-23"
  name      = "azure-identity"
  parent_id = azapi_resource.python310_runtime.id

  body = jsonencode({
    properties = {
      contentLink = {
        # CONFIRMED: py3-none-any .whl from PyPI (pure Python, works on cp310 Linux)
        uri = "https://files.pythonhosted.org/packages/49/83/a777861351e7b99e7c84ff3b36bab35e87b6e5d36e50b6905e148c696515/azure_identity-1.17.1-py3-none-any.whl"
      }
    }
  })

  schema_validation_enabled = false

  depends_on = [azapi_resource.python310_runtime]

  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "python310_pkg_azure_mgmt_resource" {
  type      = "Microsoft.Automation/automationAccounts/runtimeEnvironments/packages@2024-10-23"
  name      = "azure-mgmt-resource"
  parent_id = azapi_resource.python310_runtime.id

  body = jsonencode({
    properties = {
      contentLink = {
        uri = "https://files.pythonhosted.org/packages/73/26/1e0aa521832b6833e6ed81481bc9044a5812418deeaa86e99e6850e234f4/azure_mgmt_resource-23.1.1-py3-none-any.whl"
      }
    }
  })

  schema_validation_enabled = false

  depends_on = [azapi_resource.python310_runtime]

  lifecycle {
    ignore_changes = [body]
  }
}

resource "azapi_resource" "python310_pkg_azure_mgmt_compute" {
  type      = "Microsoft.Automation/automationAccounts/runtimeEnvironments/packages@2024-10-23"
  name      = "azure-mgmt-compute"
  parent_id = azapi_resource.python310_runtime.id

  body = jsonencode({
    properties = {
      contentLink = {
        uri = "https://files.pythonhosted.org/packages/6a/e7/1b45dc94cb16be38c5c13cc2844e0bd237e60ee54fbf3c5eddc8ff351f3b/azure_mgmt_compute-30.6.0-py3-none-any.whl"
      }
    }
  })

  schema_validation_enabled = false

  depends_on = [azapi_resource.python310_runtime]

  lifecycle {
    ignore_changes = [body]
  }
}

# ==============================================================================
# PowerShell 5.1 Runbooks
#
# azurerm_automation_runbook with content inline.
# No runtime_environment_name needed — PS 5.1 uses the system-generated env.
# runbook_type = "PowerShell" with no runtime env binding → defaults to PS 5.1
# system-generated env (PowerShell-5.1).
# ==============================================================================

resource "azurerm_automation_runbook" "ps51_get_azure_info" {
  name                    = "Get-AzureInfo-PS51"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
  log_verbose             = true
  log_progress            = true
  description             = "PowerShell 5.1 runbook - Get Azure subscription and resource information"
  runbook_type            = "PowerShell"
  content                 = file("${path.module}/runbooks/Get-AzureInfo-PS51.ps1")
  tags                    = var.tags
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
  content                 = file("${path.module}/runbooks/Get-VMInventory-PS51.ps1")
  tags                    = var.tags
}

# ==============================================================================
# PowerShell 7.4 Runbooks
#
# RESEARCH: azurerm_automation_runbook supports runtime_environment_name (Optional).
# Ref: hashicorp/terraform-provider-azurerm main branch docs. API: 2024-10-23.
# Using native azurerm + content inline eliminates all local-exec blocks.
# runbook_type = "PowerShell" + runtime_environment_name = "PS74" → binds to
# our custom PS 7.4 runtime environment.
#
# NOTE: runbook files on disk are named *-PS72.ps1 for backward compat with
# tester baselines from round 1, but the Azure runbook names are *-PS74 (which
# is what the portal and az CLI see).
# ==============================================================================

resource "azurerm_automation_runbook" "ps74_parallel_processing" {
  name                     = "Demo-ParallelProcessing-PS74"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  automation_account_name  = var.automation_account_name
  log_verbose              = true
  log_progress             = true
  description              = "PowerShell 7.4 runbook - Demonstrates parallel processing with ForEach-Object -Parallel"
  runbook_type             = "PowerShell"
  runtime_environment_name = "PS74"
  content                  = file("${path.module}/runbooks/Demo-ParallelProcessing-PS72.ps1")
  tags                     = var.tags

  depends_on = [azapi_resource.ps74_runtime]
}

resource "azurerm_automation_runbook" "ps74_modern_features" {
  name                     = "Demo-ModernFeatures-PS74"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  automation_account_name  = var.automation_account_name
  log_verbose              = true
  log_progress             = true
  description              = "PowerShell 7.4 runbook - Demonstrates ternary operators, null coalescing, and pipeline parallelization"
  runbook_type             = "PowerShell"
  runtime_environment_name = "PS74"
  content                  = file("${path.module}/runbooks/Demo-ModernFeatures-PS72.ps1")
  tags                     = var.tags

  depends_on = [azapi_resource.ps74_runtime]
}

resource "azurerm_automation_runbook" "ps74_resource_report" {
  name                     = "Get-ResourceReport-PS74"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  automation_account_name  = var.automation_account_name
  log_verbose              = true
  log_progress             = true
  description              = "PowerShell 7.4 runbook - Generate comprehensive Azure resource report"
  runbook_type             = "PowerShell"
  runtime_environment_name = "PS74"
  content                  = file("${path.module}/runbooks/Get-ResourceReport-PS72.ps1")
  tags                     = var.tags

  depends_on = [azapi_resource.ps74_runtime]
}

# ==============================================================================
# Python 3.10 Runbooks
#
# RESEARCH: runbook_type = "Python3" is valid (confirmed in azurerm docs).
# runtime_environment_name = "Python310" binds to our custom env.
# content inline — no local-exec needed.
# ==============================================================================

resource "azurerm_automation_runbook" "python_hello_world" {
  name                     = "Hello-World-Python"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  automation_account_name  = var.automation_account_name
  log_verbose              = true
  log_progress             = true
  description              = "Python 3.10 runbook - Hello World"
  runbook_type             = "Python3"
  runtime_environment_name = "Python310"
  content                  = file("${path.module}/runbooks/hello_world.py")
  tags                     = var.tags

  depends_on = [azapi_resource.python310_runtime]
}

resource "azurerm_automation_runbook" "python_resource_inventory" {
  name                     = "Get-ResourceInventory-Python"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  automation_account_name  = var.automation_account_name
  log_verbose              = true
  log_progress             = true
  description              = "Python 3.10 runbook - Get Azure resource inventory"
  runbook_type             = "Python3"
  runtime_environment_name = "Python310"
  content                  = file("${path.module}/runbooks/get_resource_inventory.py")
  tags                     = var.tags

  depends_on = [azapi_resource.python310_runtime]
}

resource "azurerm_automation_runbook" "python_vm_management" {
  name                     = "Manage-VMs-Python"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  automation_account_name  = var.automation_account_name
  log_verbose              = true
  log_progress             = true
  description              = "Python 3.10 runbook - Start/Stop VMs using Azure SDK"
  runbook_type             = "Python3"
  runtime_environment_name = "Python310"
  content                  = file("${path.module}/runbooks/manage_vms.py")
  tags                     = var.tags

  depends_on = [azapi_resource.python310_runtime]
}

resource "azurerm_automation_runbook" "python_tag_compliance" {
  name                     = "Check-TagCompliance-Python"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  automation_account_name  = var.automation_account_name
  log_verbose              = true
  log_progress             = true
  description              = "Python 3.10 runbook - Check resource tag compliance"
  runbook_type             = "Python3"
  runtime_environment_name = "Python310"
  content                  = file("${path.module}/runbooks/check_tag_compliance.py")
  tags                     = var.tags

  depends_on = [azapi_resource.python310_runtime]
}
