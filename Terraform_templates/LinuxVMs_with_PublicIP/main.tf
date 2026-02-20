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

module "common_infra" {
  source = "../../modules/common_infra"

  resource_group_name   = var.resource_group_name
  location              = var.location
  nsg_name              = var.nsg_name
  subnet_id             = data.azurerm_subnet.subnet.id
  management_port       = 22
  management_rule_name  = "Allow-SSH"
  enable_https_inbound  = false
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

# Public IPs
resource "azurerm_public_ip" "pip" {
  count               = var.vm_count
  name                = "${var.vm_name_prefix}${var.vm_number_start + count.index}${var.vm_name_suffix}-pip"
  location            = var.location
  resource_group_name = module.common_infra.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NICs
resource "azurerm_network_interface" "nic" {
  count               = var.vm_count
  name                = "${var.vm_name_prefix}${var.vm_number_start + count.index}${var.vm_name_suffix}-nic"
  location            = var.location
  resource_group_name = module.common_infra.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"

    public_ip_address_id = azurerm_public_ip.pip[count.index].id
  }
}

# Linux Virtual Machines (SSH key auth)
resource "azurerm_linux_virtual_machine" "vm" {
  count               = var.vm_count
  name                = "${var.vm_name_prefix}${var.vm_number_start + count.index}${var.vm_name_suffix}"
  resource_group_name = module.common_infra.resource_group_name
  location            = var.location
  size                = var.vm_size

  admin_username                  = var.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

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
