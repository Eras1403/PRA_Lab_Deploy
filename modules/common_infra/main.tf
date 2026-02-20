# Erstellt eine dedizierte Resource Group für die Compute-Ressourcen.
resource "azurerm_resource_group" "compute" {
  # Name der Resource Group, kommt aus dem aufrufenden Template.
  name = var.resource_group_name
  # Azure-Region, in der die Resource Group und abhängige Ressourcen erstellt werden.
  location = var.location
}

# Erstellt eine Network Security Group (NSG), die später am Subnetz gebunden wird.
resource "azurerm_network_security_group" "nsg" {
  # Logischer Name der NSG in Azure.
  name = var.nsg_name
  # Region der NSG (muss zur Resource Group passen).
  location = var.location
  # Verknüpfung zur oben erstellten Resource Group.
  resource_group_name = azurerm_resource_group.compute.name
}

# Erlaubt ausgehenden HTTP/HTTPS-Traffic ins Internet.
resource "azurerm_network_security_rule" "web_outbound" {
  # Eindeutiger Regelname.
  name = "Allow-Internet-Outbound"
  # Priorität: niedriger Wert = höhere Priorität.
  priority = 100
  # Regelrichtung ist ausgehend.
  direction = "Outbound"
  # Traffic wird erlaubt.
  access = "Allow"
  # Nur TCP-Protokoll.
  protocol = "Tcp"
  # Beliebiger Quellport.
  source_port_range = "*"
  # Zielports 80 und 443.
  destination_port_ranges = ["80", "443"]
  # Beliebige Quelle.
  source_address_prefix = "*"
  # Ziel ist das Internet.
  destination_address_prefix = "Internet"
  # Resource Group-Kontext für die Regel.
  resource_group_name = azurerm_resource_group.compute.name
  # Zuordnung der Regel zur NSG.
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Blockiert sämtlichen restlichen ausgehenden Traffic (Default-Deny für Egress).
resource "azurerm_network_security_rule" "deny_outbound_all" {
  # Eindeutiger Regelname.
  name = "Deny-OutboundAll-Any-out-4096"
  # Sehr niedrige Priorität, damit spezifische Allow-Regeln vorher greifen.
  priority = 4096
  # Regel gilt für ausgehenden Traffic.
  direction = "Outbound"
  # Traffic wird verweigert.
  access = "Deny"
  # Alle Protokolle.
  protocol = "Any"
  # Beliebiger Quellport.
  source_port_range = "*"
  # Beliebiger Zielport.
  destination_port_range = "*"
  # Beliebige Quelle.
  source_address_prefix = "*"
  # Beliebiges Ziel.
  destination_address_prefix = "*"
  # Resource Group-Kontext für die Regel.
  resource_group_name = azurerm_resource_group.compute.name
  # Zuordnung der Regel zur NSG.
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Erlaubt eingehenden Management-Traffic (z. B. SSH/RDP) gemäß Parametern.
resource "azurerm_network_security_rule" "management_inbound" {
  # Regelname wird von außen übergeben (z. B. Allow-SSH oder Allow-RDP).
  name = var.management_rule_name
  # Priorität wird als Variable konfiguriert.
  priority = var.management_rule_priority
  # Regel gilt für eingehenden Traffic.
  direction = "Inbound"
  # Zugriff ist erlaubt.
  access = "Allow"
  # Management-Verkehr erfolgt über TCP.
  protocol = "Tcp"
  # Beliebiger Quellport.
  source_port_range = "*"
  # Zielport wird aus der Management-Port-Variable übernommen.
  destination_port_range = tostring(var.management_port)
  # Eingrenzung der zulässigen Quelladresse (z. B. VirtualNetwork oder Internet).
  source_address_prefix = var.management_source_prefix
  # Zieladresse bleibt offen für die jeweilige VM-IP im Subnetz.
  destination_address_prefix = "*"
  # Resource Group-Kontext für die Regel.
  resource_group_name = azurerm_resource_group.compute.name
  # Zuordnung der Regel zur NSG.
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Optional: erlaubt eingehendes HTTPS aus dem Internet.
resource "azurerm_network_security_rule" "https_inbound" {
  # Erzeugt die Regel nur, wenn HTTPS explizit aktiviert ist.
  count = var.enable_https_inbound ? 1 : 0
  # Fester Regelname für HTTPS.
  name = "Allow-HTTPS-Inbound"
  # Priorität der HTTPS-Regel.
  priority = var.https_inbound_priority
  # Regel gilt für eingehenden Traffic.
  direction = "Inbound"
  # Zugriff wird erlaubt.
  access = "Allow"
  # HTTPS läuft über TCP.
  protocol = "Tcp"
  # Beliebiger Quellport.
  source_port_range = "*"
  # Zielport 443 für HTTPS.
  destination_port_range = "443"
  # Quellen aus dem Internet.
  source_address_prefix = "Internet"
  # Zieladresse bleibt offen für Ziel-IPs im Subnetz.
  destination_address_prefix = "*"
  # Resource Group-Kontext für die Regel.
  resource_group_name = azurerm_resource_group.compute.name
  # Zuordnung der Regel zur NSG.
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Verknüpft die NSG mit dem bestehenden Subnetz.
resource "azurerm_subnet_network_security_group_association" "subnet_nsg" {
  # Ziel-Subnetz-ID aus dem aufrufenden Modul.
  subnet_id = var.subnet_id
  # NSG-ID der in diesem Modul erstellten NSG.
  network_security_group_id = azurerm_network_security_group.nsg.id
}
