terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
}

# Existing network
data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group
}

data "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = var.vnet_resource_group
}

# Workload Resource Group
resource "azurerm_resource_group" "compute" {
  name     = var.resource_group_name
  location = var.location
}

# Linux image mapping (STRICT)
locals {
  linux_images = {
    "rhel-9.4" = {
      publisher = "RedHat"
      offer     = "RHEL"
      sku       = "9_4"
    }
    "suse-15" = {
      publisher = "SUSE"
      offer     = "sles-15-sp6"
      sku       = "gen2"
    }
    "ubuntu-24.04" = {
      publisher = "Canonical"
      offer     = "ubuntu-24_04-lts"
      sku       = "server"
    }
    "debian-12" = {
      publisher = "Debian"
      offer     = "debian-12"
      sku       = "12"
    }
    "fedora-40" = {
      publisher = "Fedora"
      offer     = "fedora-40"
      sku       = "40"
    }
  }
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = azurerm_resource_group.compute.name
}

# Allow SSH inbound
#resource "azurerm_network_security_rule" "https_inbound" {
#  name                        = "Allow-HTTPS-Inbound"
#  priority                    = 100
#  direction                   = "Inbound"
#  access                      = "Allow"
#  protocol                    = "Tcp"
#  source_port_range           = "*"
#  destination_port_range      = "443"
#  source_address_prefix       = "Internet"
#  destination_address_prefix  = "*"
# resource_group_name         = azurerm_resource_group.compute.name
#  network_security_group_name = azurerm_network_security_group.nsg.name
#}

resource "azurerm_network_security_rule" "web_outbound" {
  name                        = "Allow-Internet-Outbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = azurerm_resource_group.compute.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "Deny-OutboundAll" {
  name                        = "Deny-OutboundAll-Any-out-4096"
  priority                    = 4096
  direction                   = "Outbound"
  access                      = "Deny"
  protocol                    = "Any"
  source_port_range           = "*"
  destination_port_ranges      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.compute.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# NEW: Allow RDP from Virtual Network
resource "azurerm_network_security_rule" "rdp_inbound" {
  name                        = "Allow-SSH"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.compute.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "subnet_nsg" {
  subnet_id                 = data.azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Public IPs
resource "azurerm_public_ip" "pip" {
  count               = var.vm_count
  name                = "${var.vm_name_prefix}${var.vm_number_start + count.index}${var.vm_name_suffix}-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.compute.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NICs
resource "azurerm_network_interface" "nic" {
  count               = var.vm_count
  name                = "${var.vm_name_prefix}${var.vm_number_start + count.index}${var.vm_name_suffix}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"

    public_ip_address_id = azurerm_public_ip.pip[count.index].id
  }
}

# Linux Virtual Machines (PASSWORD AUTH)
resource "azurerm_linux_virtual_machine" "vm" {
  count               = var.vm_count
  name                = "${var.vm_name_prefix}${var.vm_number_start + count.index}${var.vm_name_suffix}"
  resource_group_name = azurerm_resource_group.compute.name
  location            = var.location
  size                = var.vm_size

  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = local.linux_images[var.linux_distro].publisher
    offer     = local.linux_images[var.linux_distro].offer
    sku       = local.linux_images[var.linux_distro].sku
    version   = "latest"
  }
}
