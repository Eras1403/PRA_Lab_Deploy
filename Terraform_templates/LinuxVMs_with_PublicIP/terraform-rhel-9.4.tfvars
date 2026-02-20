resource_group_name = "rg_sandbox_north_bt_jump_client_point_Linux"
location            = "Switzerland North"

vm_size         = "Standard_B2ms"
admin_username  = "LocalAdmin"
vm_count        = 1
vm_name_prefix  = "zurva"
vm_number_start = 8020
vm_name_suffix	= "tri"

linux_distro = "rhel-9.4"

vnet_name           = "vnet_sandbox_north"
subnet_name         = "snet_sandbox_north_bt-jump-client-Linux"
vnet_resource_group = "rg_sandbox_north_network"

nsg_name = "nsg_snet_sandbox_north_bt-jump-client-Linux"

admin_ssh_public_key = "ssh-rsa REPLACE_WITH_YOUR_PUBLIC_KEY"
