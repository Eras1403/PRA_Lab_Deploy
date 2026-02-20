# Gibt den Namen der vom Modul erzeugten Resource Group zurück.
output "resource_group_name" {
  # Referenz auf den Azure-Ressourcennamen.
  value = azurerm_resource_group.compute.name
}

# Gibt die ID der vom Modul erzeugten Resource Group zurück.
output "resource_group_id" {
  # Referenz auf die Azure-Ressourcen-ID.
  value = azurerm_resource_group.compute.id
}

# Gibt die ID der erstellten Network Security Group zurück.
output "nsg_id" {
  # Referenz auf die NSG-ID.
  value = azurerm_network_security_group.nsg.id
}
