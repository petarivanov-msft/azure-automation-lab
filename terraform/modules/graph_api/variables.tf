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

variable "managed_identity_principal_id" {
  description = "Principal ID of the Automation Account managed identity"
  type        = string
}

variable "skip_graph_permissions" {
  description = "Skip Graph API app role assignments (set true if you lack Application Administrator / Privileged Role Administrator in Entra ID). Runbooks will be deployed but won't work until permissions are granted manually."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
