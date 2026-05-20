terraform {
  required_version = ">= 1.3.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # Bumped from ~> 3.0 to ~> 4.0 to gain:
      #   runtime_environment_name on azurerm_automation_runbook (added in 4.59.0)
      # Breaking change audit vs 3.x:
      #   azurerm_automation_account: removed deprecated encryption.key_source (not used here)
      #   azurerm_automation_runbook: no breaking changes
      #   azurerm_automation_module: no breaking changes
      #   azurerm_automation_hybrid_runbook_worker: no breaking changes
      # Safe to bump. See: hashicorp/terraform-provider-azurerm CHANGELOG + 4.0 upgrade guide.
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = true
    }
  }
}

provider "azuread" {}

# RESEARCH: azapi provider auth args confirmed via
# https://raw.githubusercontent.com/Azure/terraform-provider-azapi/main/docs/index.md
# Schema section: use_cli (Boolean, default true), use_msi (Boolean, default false).
# Spelling confirmed: use_cli, use_msi — not use-cli or useMSI.
#
# FIX (bug from tester round 2): On Arc-enrolled Windows boxes, azapi auto-tries
# Arc managed identity, hits ACL deny on token file, never falls through to az CLI.
# Setting use_msi = false forces CLI-only auth path. Safe for Cloud Shell users
# (they already use CLI) and unblocks Arc-enrolled workstations.
# Env-var equivalents: ARM_USE_CLI=true, ARM_USE_MSI=false
provider "azapi" {
  use_cli = true
  use_msi = false
}
