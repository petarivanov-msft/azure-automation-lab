variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-hybrid-worker-lab"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "hwlab"
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "tags" {
  type = map(string)
  default = {
    Environment = "Lab"
    Purpose     = "HybridWorker"
  }
}

variable "allowed_source_ip" {
  description = "Source IP or CIDR allowed to RDP to the VM. Use '*' for any (not recommended for production)."
  type        = string
  default     = "*"
}

variable "run_test_runbook" {
  description = "Auto-run the test runbook after deployment"
  type        = bool
  default     = true
}
