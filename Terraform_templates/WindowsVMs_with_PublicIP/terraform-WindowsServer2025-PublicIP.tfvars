resource_group_name = "rg_sandbox_north_bt_jump_clients_Windows"
location            = "Switzerland North"

vnet_name             = "vnet_sandbox_north"
vnet_resource_group   = "rg_sandbox_north_network"
subnet_name           = "snet_sandbox_north_bt-jump-client-Windows"
nsg_name              = "nsg_sandbox_north_bt-jump-client-Windows"

vm_size        = "Standard_B2ms"
admin_username = "LocalAdmin"

vm_count        = 2
vm_name_prefix  = "zurva"
vm_number_start = 8010
vm_name_suffix  = "tri"

