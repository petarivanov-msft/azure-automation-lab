variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "automation_account_name" {
  description = "Name of the Automation Account"
  type        = string
}

variable "automation_account_id" {
  description = "ID of the Automation Account"
  type        = string
}

variable "automation_identity_principal_id" {
  description = "Principal ID of the Automation Account managed identity"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet for VMs"
  type        = string
}

variable "vm_admin_username" {
  description = "Admin username for VMs"
  type        = string
}

variable "vm_admin_password" {
  description = "Admin password for VMs"
  type        = string
  sensitive   = true
}

variable "resource_group_id" {
  description = "ID of the resource group for RBAC scoping"
  type        = string
}

variable "run_test_runbook" {
  description = "Whether to automatically run the test runbook on hybrid workers after deployment"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
