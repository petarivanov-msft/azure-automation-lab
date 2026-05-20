variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "automation_account_id" {
  description = "Resource ID of the Automation Account"
  type        = string
}

variable "automation_account_name" {
  description = "Name of the Automation Account"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
