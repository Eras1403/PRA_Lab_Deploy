variable "resource_group_name" {
  type        = string
  description = "Resource group where VMs and NSG will be deployed"
}

variable "location" {
  type        = string
  description = "Azure region"
}

variable "vnet_name" {
  type        = string
  description = "Existing virtual network name"
}

variable "vnet_resource_group" {
  type        = string
  description = "Resource group of the existing VNet"
}

variable "subnet_name" {
  type        = string
  description = "Name of the subnet to attach VMs"
}

variable "nsg_name" {
  type        = string
  description = "Name of the NSG to create or attach"
}

variable "vm_size" {
  type        = string
  description = "Size of the VMs"
}

variable "admin_username" {
  type        = string
  description = "Admin username for VMs"
}

variable "admin_password" {
  description = "Admin password for Windows VMs (will be prompted)"
  type        = string
  sensitive   = true
}

variable "vm_count" {
  type        = number
  description = "Number of VMs to deploy"
}

variable "vm_name_prefix" {
  type        = string
  description = "Prefix for VM names"
}

variable "vm_number_start" {
  type        = number
  description = "Starting number for VM names"
}

variable "vm_name_suffix" {
  type        = string
  description = "Suffix for VM names"
}
