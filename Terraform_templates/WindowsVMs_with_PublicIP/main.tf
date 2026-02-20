# Definiert die Terraform-Anforderungen für das Windows-Template.
terraform {
  # Liste der benötigten Provider.
  required_providers {
    # Konfiguration des AzureRM-Providers.
    azurerm = {
      # Registry-Quelle des Providers.
      source = "hashicorp/azurerm"
      # Verwendete Hauptversion des Providers.
      version = "~> 3.100"
    }
  }
}

# Initialisiert den AzureRM-Provider.
provider "azurerm" {
  # Aktiviert Provider-Features mit Standardeinstellungen.
  features {}
}

# Liest das bereits existierende Virtual Network.
data "azurerm_virtual_network" "vnet" {
  # Name des vorhandenen VNets.
  name = var.vnet_name
  # Resource Group des vorhandenen VNets.
  resource_group_name = var.vnet_resource_group
}

# Liest das bereits existierende Subnetz aus dem VNet.
data "azurerm_subnet" "subnet" {
  # Name des Ziel-Subnetzes.
  name = var.subnet_name
  # Name des übergeordneten VNets.
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  # Resource Group, in der das Subnetz liegt.
  resource_group_name = var.vnet_resource_group
}

# Verwendet das gemeinsame Modul für RG/NSG/Regeln.
module "common_infra" {
  # Relativer Pfad zum gemeinsamen Modul.
  source = "../../modules/common_infra"

  # Name der Ziel-Resource-Group.
  resource_group_name = var.resource_group_name
  # Azure-Region.
  location = var.location
  # Name der anzulegenden NSG.
  nsg_name = var.nsg_name
  # Subnetz-ID für die NSG-Assoziation.
  subnet_id = data.azurerm_subnet.subnet.id
  # Management-Port für Windows (RDP).
  management_port = 3389
  # Anzeigename der Management-Regel.
  management_rule_name = "Allow-RDP"
  # HTTPS-Inbound ist für dieses Szenario aktiviert.
  enable_https_inbound = true
}

# Erstellt pro Windows-VM eine öffentliche IP.
resource "azurerm_public_ip" "pip" {
  # Anzahl entsprechend der gewünschten VM-Anzahl.
  count = var.vm_count
  # Namensschema für Public IPs.
  name = "${var.vm_name_prefix}${var.vm_number_start + count.index}${var.vm_name_suffix}-pip"
  # Azure-Region.
  location = var.location
  # Ziel-Resource-Group aus dem Modul.
  resource_group_name = module.common_infra.resource_group_name
  # Statische Public IP.
  allocation_method = "Static"
  # Standard-SKU.
  sku = "Standard"
}

# Erstellt pro VM ein Netzwerkinterface.
resource "azurerm_network_interface" "nic" {
  # Anzahl entsprechend der gewünschten VM-Anzahl.
  count = var.vm_count
  # Namensschema für NICs.
  name = "${var.vm_name_prefix}${var.vm_number_start + count.index}${var.vm_name_suffix}-nic"
  # Azure-Region.
  location = var.location
  # Ziel-Resource-Group aus dem Modul.
  resource_group_name = module.common_infra.resource_group_name

  # Definiert die primäre IP-Konfiguration.
  ip_configuration {
    # Name der IP-Konfiguration.
    name = "ipconfig1"
    # Ziel-Subnetz.
    subnet_id = data.azurerm_subnet.subnet.id
    # Private IP dynamisch vergeben.
    private_ip_address_allocation = "Dynamic"
    # Verknüpft die passende Public IP.
    public_ip_address_id = azurerm_public_ip.pip[count.index].id
  }
}

# Erstellt die Windows-VMs.
resource "azurerm_windows_virtual_machine" "vm" {
  # Anzahl entsprechend der gewünschten VM-Anzahl.
  count = var.vm_count
  # Namensschema für VMs.
  name = "${var.vm_name_prefix}${var.vm_number_start + count.index}${var.vm_name_suffix}"
  # Ziel-Resource-Group aus dem Modul.
  resource_group_name = module.common_infra.resource_group_name
  # Azure-Region.
  location = var.location
  # Größe/SKU der VM.
  size = var.vm_size
  # Lokaler Administratorname.
  admin_username = var.admin_username
  # Lokales Administratorpasswort.
  admin_password = var.admin_password

  # Hängt die zuvor erzeugte NIC an die VM.
  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id
  ]

  # Konfiguration des Betriebssystem-Datenträgers.
  os_disk {
    # Cache-Modus.
    caching = "ReadWrite"
    # Storage-Typ.
    storage_account_type = "Standard_LRS"
  }

  # Definiert das Windows-Image aus dem Azure Marketplace.
  source_image_reference {
    # Publisher des Images.
    publisher = "MicrosoftWindowsServer"
    # Offer des Images.
    offer = "WindowsServer"
    # SKU des Images.
    sku = "2025-Datacenter"
    # Immer die aktuelle Version.
    version = "latest"
  }
}
