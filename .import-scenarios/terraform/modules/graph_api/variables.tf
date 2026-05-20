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

variable "managed_identity_principal_id" {
  description = "Principal ID of the Automation Account managed identity"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
