# Ziel-Resource-Group für die Windows-Bereitstellung.
resource_group_name = "rg_sandbox_north_bt_jump_clients_Windows"
# Azure-Region der Bereitstellung.
location = "Switzerland North"

# Name des bestehenden Virtual Networks.
vnet_name = "vnet_sandbox_north"
# Resource Group des bestehenden VNets.
vnet_resource_group = "rg_sandbox_north_network"
# Name des vorhandenen Ziel-Subnetzes.
subnet_name = "snet_sandbox_north_bt-jump-client-Windows"
# Name der zu erstellenden Network Security Group.
nsg_name = "nsg_sandbox_north_bt-jump-client-Windows"

# Größe/SKU der Windows-VMs.
vm_size = "Standard_B2ms"
# Lokaler Administratorname auf den VMs.
admin_username = "LocalAdmin"

# Anzahl der bereitzustellenden VMs.
vm_count = 2
# Präfix für VM-Namen.
vm_name_prefix = "zurva"
# Startnummer der VM-Nummerierung.
vm_number_start = 8010
# Suffix für VM-Namen.
vm_name_suffix = "tri"
