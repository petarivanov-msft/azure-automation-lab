terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
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
      version = "~> 3.6"
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
