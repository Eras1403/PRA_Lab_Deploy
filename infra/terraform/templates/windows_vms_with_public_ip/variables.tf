# Name der Resource Group für die Windows-Ressourcen.
variable "resource_group_name" {
  # Datentyp ist String.
  type = string
  # Zweckbeschreibung der Variable.
  description = "Resource group where VMs and NSG will be deployed"
}

# Azure-Region der Bereitstellung.
variable "location" {
  # Datentyp ist String.
  type = string
  # Zweckbeschreibung der Variable.
  description = "Azure region"
}

# Name des bestehenden Virtual Networks.
variable "vnet_name" {
  # Datentyp ist String.
  type = string
  # Zweckbeschreibung der Variable.
  description = "Existing virtual network name"
}

# Resource Group des bestehenden VNets.
variable "vnet_resource_group" {
  # Datentyp ist String.
  type = string
  # Zweckbeschreibung der Variable.
  description = "Resource group of the existing VNet"
}

# Name des bestehenden Subnetzes.
variable "subnet_name" {
  # Datentyp ist String.
  type = string
  # Zweckbeschreibung der Variable.
  description = "Name of the subnet to attach VMs"
}

# Name der zu erstellenden NSG.
variable "nsg_name" {
  # Datentyp ist String.
  type = string
  # Zweckbeschreibung der Variable.
  description = "Name of the NSG to create or attach"
}

# VM-Größe/SKU für die Windows-Instanzen.
variable "vm_size" {
  # Datentyp ist String.
  type = string
  # Zweckbeschreibung der Variable.
  description = "Size of the VMs"
}

# Lokaler Admin-Benutzername auf der VM.
variable "admin_username" {
  # Datentyp ist String.
  type = string
  # Zweckbeschreibung der Variable.
  description = "Admin username for VMs"
}

# Lokales Admin-Passwort auf der VM.
variable "admin_password" {
  # Zweckbeschreibung der Variable.
  description = "Admin password for Windows VMs (will be prompted)"
  # Datentyp ist String.
  type = string
  # Wert wird als sensitiv behandelt.
  sensitive = true
}

# Anzahl der zu erstellenden Windows-VMs.
variable "vm_count" {
  # Datentyp ist Zahl.
  type = number
  # Zweckbeschreibung der Variable.
  description = "Number of VMs to deploy"
}

# Präfix für automatisch generierte VM-Namen.
variable "vm_name_prefix" {
  # Datentyp ist String.
  type = string
  # Zweckbeschreibung der Variable.
  description = "Prefix for VM names"
}

# Startnummer für die VM-Namenszählung.
variable "vm_number_start" {
  # Datentyp ist Zahl.
  type = number
  # Zweckbeschreibung der Variable.
  description = "Starting number for VM names"
}

# Suffix für automatisch generierte VM-Namen.
variable "vm_name_suffix" {
  # Datentyp ist String.
  type = string
  # Zweckbeschreibung der Variable.
  description = "Suffix for VM names"
}
