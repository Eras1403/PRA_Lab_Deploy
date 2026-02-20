# Name der Resource Group, die vom Modul erstellt wird.
variable "resource_group_name" {
  # Der Wert muss als String übergeben werden.
  type = string
}

# Azure-Region für alle im Modul erstellten Ressourcen.
variable "location" {
  # Der Wert muss als String übergeben werden.
  type = string
}

# Name der anzulegenden Network Security Group.
variable "nsg_name" {
  # Der Wert muss als String übergeben werden.
  type = string
}

# ID des bestehenden Subnetzes, an das die NSG gebunden wird.
variable "subnet_id" {
  # Der Wert muss als String übergeben werden.
  type = string
}

# Management-Port (z. B. 22 für SSH oder 3389 für RDP).
variable "management_port" {
  # Der Wert muss numerisch sein.
  type = number
}

# Anzeigename der Management-Inbound-Regel.
variable "management_rule_name" {
  # Der Wert muss als String übergeben werden.
  type = string
}

# Quelladress-Präfix für die Management-Regel.
variable "management_source_prefix" {
  # Der Wert muss als String übergeben werden.
  type = string
  # Standardmäßig ist nur das virtuelle Netzwerk erlaubt.
  default = "VirtualNetwork"
}

# Priorität der Management-Inbound-Regel.
variable "management_rule_priority" {
  # Der Wert muss numerisch sein.
  type = number
  # Standardpriorität für die Management-Regel.
  default = 110
}

# Schaltet optional eine HTTPS-Inbound-Regel ein.
variable "enable_https_inbound" {
  # Boolescher Schalter (true/false).
  type = bool
  # Standardmäßig deaktiviert.
  default = false
}

# Priorität der optionalen HTTPS-Inbound-Regel.
variable "https_inbound_priority" {
  # Der Wert muss numerisch sein.
  type = number
  # Standardpriorität für HTTPS.
  default = 120
}
