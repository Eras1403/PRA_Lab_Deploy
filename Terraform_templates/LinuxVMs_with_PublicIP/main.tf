# Definiert Terraform- und Provider-Anforderungen für dieses Template.
terraform {
  # Legt fest, welche Provider benötigt werden.
  required_providers {
    # AzureRM-Provider-Konfiguration.
    azurerm = {
      # Provider-Quelle im Registry Namespace.
      source = "hashicorp/azurerm"
      # Getestete Hauptversion des AzureRM-Providers.
      version = "~> 3.100"
    }
  }
}

# Initialisiert den AzureRM-Provider.
provider "azurerm" {
  # Aktiviert Provider-Features mit Standardwerten.
  features {}
}

# Liest ein bereits existierendes virtuelles Netzwerk (VNet).
data "azurerm_virtual_network" "vnet" {
  # Name des bestehenden VNets.
  name = var.vnet_name
  # Resource Group des bestehenden VNets.
  resource_group_name = var.vnet_resource_group
}

# Liest ein bestehendes Subnetz aus dem oben referenzierten VNet.
data "azurerm_subnet" "subnet" {
  # Name des Subnetzes.
  name = var.subnet_name
  # Name des VNets, aus dem das Subnetz gelesen wird.
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  # Resource Group des VNets/Subnetzes.
  resource_group_name = var.vnet_resource_group
}

# Wiederverwendbares Modul für RG/NSG/Regeln und NSG-Subnetz-Zuordnung.
module "common_infra" {
  # Pfad zum gemeinsamen Infrastruktur-Modul.
  source = "../../modules/common_infra"

  # Name der Ziel-Resource-Group.
  resource_group_name = var.resource_group_name
  # Azure-Region der Bereitstellung.
  location = var.location
  # Name der anzulegenden NSG.
  nsg_name = var.nsg_name
  # Subnetz-ID für die NSG-Assoziation.
  subnet_id = data.azurerm_subnet.subnet.id
  # Management-Port für Linux-VMs (SSH).
  management_port = 22
  # Anzeigename der Management-Regel.
  management_rule_name = "Allow-SSH"
  # HTTPS-Inbound-Regel für Linux in diesem Template deaktiviert.
  enable_https_inbound = false
}

# Lokale Werte: Mapping unterstützter Linux-Images und optionaler GUI/VNC-Kommandos.
locals {
  # Zulässige Linux-Distributionen inklusive Marketplace-Metadaten.
  linux_images = {
    # Red Hat Enterprise Linux 9.4.
    "rhel-9.4" = {
      publisher = "RedHat"
      offer = "RHEL"
      sku = "9_4"
    }
    # SUSE Linux Enterprise 15.
    "suse-15" = {
      publisher = "SUSE"
      offer = "sles-15-sp6"
      sku = "gen2"
    }
    # Ubuntu Server 24.04 LTS.
    "ubuntu-24.04" = {
      publisher = "Canonical"
      offer = "ubuntu-24_04-lts"
      sku = "server"
    }
    # Debian 12.
    "debian-12" = {
      publisher = "Debian"
      offer = "debian-12"
      sku = "12"
    }
    # Fedora 40.
    "fedora-40" = {
      publisher = "Fedora"
      offer = "fedora-40"
      sku = "40"
    }
  }

  # Installationskommandos für optionales XFCE + VNC je Distribution.
  gui_vnc_install_commands = {
    # Ubuntu: XFCE und TigerVNC über apt.
    "ubuntu-24.04" = "sudo apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xfce4 xfce4-goodies tigervnc-standalone-server"
    # Debian: XFCE und TigerVNC über apt.
    "debian-12" = "sudo apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xfce4 xfce4-goodies tigervnc-standalone-server"
    # RHEL: GUI-Pattern und TigerVNC über dnf.
    "rhel-9.4" = "sudo dnf install -y @\"Server with GUI\" tigervnc-server"
    # Fedora: GUI-Pattern und TigerVNC über dnf.
    "fedora-40" = "sudo dnf install -y @\"Server with GUI\" tigervnc-server"
    # SUSE: XFCE-Pattern und TigerVNC über zypper.
    "suse-15" = "sudo zypper --non-interactive refresh && sudo zypper --non-interactive install -y -t pattern xfce && sudo zypper --non-interactive install -y tigervnc"
  }
}

# Erstellt pro VM eine öffentliche IP-Adresse.
resource "azurerm_public_ip" "pip" {
  # Anzahl entspricht der gewünschten VM-Anzahl.
  count = var.vm_count
  # Benennungsschema mit Prefix, laufender Nummer und Suffix.
  name = "${var.vm_name_prefix}${var.vm_number_start + count.index}${var.vm_name_suffix}-pip"
  # Region der Public IP.
  location = var.location
  # Ziel-Resource-Group aus dem gemeinsamen Modul.
  resource_group_name = module.common_infra.resource_group_name
  # Statische öffentliche IP.
  allocation_method = "Static"
  # Standard SKU für bessere Verfügbarkeit/Sicherheit.
  sku = "Standard"
}

# Erstellt pro VM ein Netzwerkinterface.
resource "azurerm_network_interface" "nic" {
  # Anzahl entspricht der gewünschten VM-Anzahl.
  count = var.vm_count
  # Benennungsschema für NICs.
  name = "${var.vm_name_prefix}${var.vm_number_start + count.index}${var.vm_name_suffix}-nic"
  # Region der NIC.
  location = var.location
  # Ziel-Resource-Group aus dem gemeinsamen Modul.
  resource_group_name = module.common_infra.resource_group_name

  # IP-Konfiguration der NIC.
  ip_configuration {
    # Name der NIC-IP-Konfiguration.
    name = "ipconfig1"
    # Subnetz, in dem die NIC hängt.
    subnet_id = data.azurerm_subnet.subnet.id
    # Private IP wird dynamisch vergeben.
    private_ip_address_allocation = "Dynamic"
    # Bindet die zuvor erzeugte Public IP an die NIC.
    public_ip_address_id = azurerm_public_ip.pip[count.index].id
  }
}

# Erstellt die Linux-VMs mit SSH-Key-Authentifizierung.
resource "azurerm_linux_virtual_machine" "vm" {
  # Anzahl entspricht der gewünschten VM-Anzahl.
  count = var.vm_count
  # Benennungsschema für VMs.
  name = "${var.vm_name_prefix}${var.vm_number_start + count.index}${var.vm_name_suffix}"
  # Ziel-Resource-Group aus dem gemeinsamen Modul.
  resource_group_name = module.common_infra.resource_group_name
  # Region der VM.
  location = var.location
  # VM-Größe (SKU).
  size = var.vm_size

  # Administrator-Benutzername.
  admin_username = var.admin_username
  # Erzwingt SSH-Key statt Passwort-Login.
  disable_password_authentication = true

  # Hinterlegt den öffentlichen SSH-Key für den Admin-Benutzer.
  admin_ssh_key {
    # Benutzername passend zum Admin-User.
    username = var.admin_username
    # Öffentlicher Schlüssel.
    public_key = var.admin_ssh_public_key
  }

  # Verknüpft die passende NIC mit der VM.
  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id
  ]

  # Konfiguration des OS-Datenträgers.
  os_disk {
    # Caching-Modus für den Datenträger.
    caching = "ReadWrite"
    # Storage-Typ für den OS-Datenträger.
    storage_account_type = "Standard_LRS"
  }

  # Referenziert das Marketplace-Image anhand der gewählten Distribution.
  source_image_reference {
    # Image-Publisher aus lokalem Mapping.
    publisher = local.linux_images[var.linux_distro].publisher
    # Image-Offer aus lokalem Mapping.
    offer = local.linux_images[var.linux_distro].offer
    # Image-SKU aus lokalem Mapping.
    sku = local.linux_images[var.linux_distro].sku
    # Immer die neueste verfügbare Version.
    version = "latest"
  }
}

# Optional: installiert GUI + VNC per Custom Script Extension für PRA-Use-Cases.
resource "azurerm_virtual_machine_extension" "install_gui_vnc" {
  # Wird nur erzeugt, wenn enable_gui_vnc=true gesetzt ist.
  count = var.enable_gui_vnc ? var.vm_count : 0

  # Name der VM-Extension je VM.
  name = "${azurerm_linux_virtual_machine.vm[count.index].name}-gui-vnc"
  # Ziel-VM-ID, auf der die Extension läuft.
  virtual_machine_id = azurerm_linux_virtual_machine.vm[count.index].id
  # Herausgeber der Extension.
  publisher = "Microsoft.Azure.Extensions"
  # Typ der Extension.
  type = "CustomScript"
  # Version des Extension-Handlers.
  type_handler_version = "2.1"

  # Übergibt das OS-spezifische Kommando an die Extension.
  settings = jsonencode({
    commandToExecute = local.gui_vnc_install_commands[var.linux_distro]
  })
}
