output "resource_group_name" {
  value = azurerm_resource_group.compute.name
}

output "resource_group_id" {
  value = azurerm_resource_group.compute.id
}

output "nsg_id" {
  value = azurerm_network_security_group.nsg.id
}
