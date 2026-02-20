# Ziel-Resource-Group für Linux-Jump-Clients.
resource_group_name = "rg_sandbox_north_bt_jump_client_point_Linux"
# Azure-Region der Bereitstellung.
location = "Switzerland North"

# Größe/SKU der Linux-VMs.
vm_size = "Standard_B2ms"
# Lokaler Admin-Benutzername.
admin_username = "LocalAdmin"
# Anzahl der zu erstellenden VMs.
vm_count = 1
# Präfix für VM-Namen.
vm_name_prefix = "zurva"
# Startnummer für VM-Namen.
vm_number_start = 8020
# Suffix für VM-Namen.
vm_name_suffix = "tri"

# Auswahl der Linux-Distribution.
linux_distro = "suse-15"

# Name des bestehenden Virtual Networks.
vnet_name = "vnet_sandbox_north"
# Name des bestehenden Subnetzes.
subnet_name = "snet_sandbox_north_bt-jump-client-Linux"
# Resource Group des bestehenden VNets.
vnet_resource_group = "rg_sandbox_north_network"

# Name der zu erstellenden NSG.
nsg_name = "nsg_sandbox_north_bt-jump-client-Linux"

# Öffentlicher SSH-Key für den Linux-Admin.
admin_ssh_public_key = "ssh-rsa REPLACE_WITH_YOUR_PUBLIC_KEY"
