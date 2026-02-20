# Name der Resource Group, in der die Linux-VMs erstellt werden.
variable "resource_group_name" {
  # Typdefinition als String.
  type = string
}

# Azure-Region für die Bereitstellung.
variable "location" {
  # Typdefinition als String.
  type = string
}

# Azure-VM-Größe (z. B. Standard_B2s).
variable "vm_size" {
  # Typdefinition als String.
  type = string
}

# Admin-Benutzername für den Linux-Login.
variable "admin_username" {
  # Typdefinition als String.
  type = string
}

# Öffentlicher SSH-Key für passwortlosen Zugriff.
variable "admin_ssh_public_key" {
  # Beschreibung des Variablenzwecks.
  description = "SSH public key for Linux VM admin access"
  # Typdefinition als String.
  type = string
  # Sensitiver Wert, damit er in Ausgaben maskiert wird.
  sensitive = true
}

# Anzahl der zu erstellenden Linux-VMs.
variable "vm_count" {
  # Typdefinition als Zahl.
  type = number
}

# Präfix für VM-Namen.
variable "vm_name_prefix" {
  # Typdefinition als String.
  type = string
}

# Suffix für VM-Namen.
variable "vm_name_suffix" {
  # Typdefinition als String.
  type = string
}

# Startnummer für die VM-Nummerierung.
variable "vm_number_start" {
  # Typdefinition als Zahl.
  type = number
}

# Name des bestehenden Virtual Networks.
variable "vnet_name" {
  # Typdefinition als String.
  type = string
}

# Name des bestehenden Subnetzes.
variable "subnet_name" {
  # Typdefinition als String.
  type = string
}

# Resource Group des bestehenden VNets.
variable "vnet_resource_group" {
  # Typdefinition als String.
  type = string
}

# Name der anzulegenden NSG.
variable "nsg_name" {
  # Typdefinition als String.
  type = string
}

# Auswahl der Linux-Distribution aus einer erlaubten Liste.
variable "linux_distro" {
  # Beschreibung der erlaubten Optionen.
  description = "Allowed Linux distributions only"
  # Typdefinition als String.
  type = string

  # Validiert die Eingabe gegen die unterstützten Distros.
  validation {
    # Bedingung: Wert muss in der Liste enthalten sein.
    condition = contains(
      ["rhel-9.4", "suse-15", "ubuntu-24.04", "debian-12", "fedora-40"],
      var.linux_distro
    )
    # Fehlermeldung bei ungültigem Wert.
    error_message = "linux_distro must be one of: rhel-9.4, suse-15, ubuntu-24.04, debian-12, fedora-40"
  }
}

# Optionales Feature für Desktop + VNC Installation.
variable "enable_gui_vnc" {
  # Zweckbeschreibung der Option.
  description = "Install an XFCE desktop and VNC server on Linux VMs for PRA VNC remote-jump use cases"
  # Typdefinition als boolesch.
  type = bool
  # Standardmäßig deaktiviert.
  default = false
}
