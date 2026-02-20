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

# Use existing network
data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group
}

data "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = var.vnet_resource_group
}

# Resource Group for workload
resource "azurerm_resource_group" "compute" {
  name     = var.resource_group_name
  location = var.location
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = azurerm_resource_group.compute.name
}

# NSG Rules
resource "azurerm_network_security_rule" "https_inbound" {
  name                        = "Allow-HTTPS-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.compute.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

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
  destination_port_ranges     = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.compute.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# NEW: Allow RDP from Virtual Network
resource "azurerm_network_security_rule" "rdp_inbound" {
  name                        = "Allow-RDP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
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

# Network Interfaces
resource "azurerm_network_interface" "nic" {
  count               = var.vm_count
  name                = "${var.vm_name_prefix}${var.vm_number_start + count.index}${var.vm_name_suffix}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip[count.index].id
  }
}

# Windows Virtual Machines
resource "azurerm_windows_virtual_machine" "vm" {
  count               = var.vm_count
  name                = "${var.vm_name_prefix}${var.vm_number_start + count.index}${var.vm_name_suffix}"
  resource_group_name = azurerm_resource_group.compute.name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-Datacenter"
    version   = "latest"
  }
}
