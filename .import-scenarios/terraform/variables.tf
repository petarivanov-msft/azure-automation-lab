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
  description = "Source IP or CIDR allowed for RDP/WinRM/SSH access. Use '*' for any (not recommended for production)."
  type        = string
  default     = "*"
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
