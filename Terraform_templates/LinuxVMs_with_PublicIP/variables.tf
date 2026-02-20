variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vm_size" {
  type = string
}

variable "admin_username" {
  type = string
}

variable "admin_ssh_public_key" {
  description = "SSH public key for Linux VM admin access"
  type        = string
  sensitive   = true
}

variable "vm_count" {
  type = number
}

variable "vm_name_prefix" {
  type = string
}

variable "vm_name_suffix" {
  type = string
}

variable "vm_number_start" {
  type = number
}

variable "vnet_name" {
  type = string
}

variable "subnet_name" {
  type = string
}

variable "vnet_resource_group" {
  type = string
}

variable "nsg_name" {
  type = string
}

variable "linux_distro" {
  description = "Allowed Linux distributions only"
  type        = string

  validation {
    condition = contains(
      ["rhel-9.4", "suse-15", "ubuntu-24.04", "debian-12", "fedora-40"],
      var.linux_distro
    )
    error_message = "linux_distro must be one of: rhel-9.4, suse-15, ubuntu-24.04, debian-12, fedora-40"
  }
}

variable "enable_gui_vnc" {
  description = "Install an XFCE desktop and VNC server on Linux VMs for PRA VNC remote-jump use cases"
  type        = bool
  default     = false
}
