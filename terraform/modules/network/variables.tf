variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "allowed_source_ip" {
  description = "Source IP or CIDR allowed for RDP/WinRM/SSH access. Use '*' for any (not recommended for production)."
  type        = string
  default     = "*"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
