variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "UK South"
}

variable "automation_account_name" {
  description = "Name of the Azure Automation Account"
  type        = string
}

variable "vm_admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureadmin"
}

variable "vm_admin_password" {
  description = "Admin password for VMs"
  type        = string
  sensitive   = true
}

variable "enable_runbooks" {
  description = "Enable runbooks module (PS 5.1, PS 7.4, Python)"
  type        = bool
  default     = true
}

variable "enable_hybrid_workers" {
  description = "Enable Hybrid Workers (Windows, Ubuntu, RHEL VMs)"
  type        = bool
  default     = true
}

variable "run_test_runbook" {
  description = "Automatically run test runbook on hybrid workers after deployment"
  type        = bool
  default     = true
}

variable "enable_graph_api" {
  description = "Enable Graph API automation scenario"
  type        = bool
  default     = false
}

variable "allowed_source_ip" {
  description = "Source IP or CIDR allowed for RDP/WinRM/SSH access. Use '*' for any (not recommended; requires acknowledge_open_nsg = true)."
  type        = string
  default     = "*"

  validation {
    # Allow a real IP/CIDR; if '*' is used, force the user to opt in via acknowledge_open_nsg.
    condition     = var.allowed_source_ip != "*" || var.acknowledge_open_nsg
    error_message = "allowed_source_ip = '*' opens RDP/WinRM/SSH to the public internet. Set acknowledge_open_nsg = true to opt in, or pass a specific IP/CIDR (e.g. \"203.0.113.4/32\")."
  }
}

variable "acknowledge_open_nsg" {
  description = "Set to true to explicitly opt in to allowed_source_ip = '*' (NSG open to internet). Required for unrestricted access; ignored otherwise."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Lab"
    Purpose     = "Azure Automation Scenarios"
    ManagedBy   = "Terraform"
  }
}
