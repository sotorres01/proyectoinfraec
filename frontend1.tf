resource "azurerm_network_security_group" "nsg_utb_front_1" {
  name                = "nsg_utb_front_1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allowSSH"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allowPublicWeb"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "allowHttps"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "public_ip_front1" {
  name                = "vm_ip_front1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  domain_name_label   = "frontend1"
}

resource "azurerm_network_interface" "vm_nic_front1" {
  name                = "vm_nic_front1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig_nic_front1"
    subnet_id                     = azurerm_subnet.utb_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip_front1.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_nic_assoc_front1" {
  network_interface_id      = azurerm_network_interface.vm_nic_front1.id
  network_security_group_id = azurerm_network_security_group.nsg_utb_front_1.id
}

resource "azurerm_linux_virtual_machine" "utb_vm_front1" {
  name                  = "frontend1_vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.vm_nic_front1.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "myOsDisk_front1"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name                   = "utbvmfront1"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh_key.public_key_openssh
  }
}

resource "local_file" "ansible_inventory_front1" {
  depends_on = [azurerm_linux_virtual_machine.utb_vm_front1]
  content  =templatefile("inventory.tftpl", {
    ip_addrs = [azurerm_public_ip.public_ip_front1.ip_address]
    ssh_keyfile = format("%s/%s", abspath(path.root), "priv_key.ssh")

  })
  filename = "inventory_front1"
}

resource "null_resource" "run_ansible_front1" {
  depends_on = [azurerm_linux_virtual_machine.utb_vm_front1]

  provisioner "local-exec" {
    command = "sleep 30 && ansible-playbook -i ${local_file.ansible_inventory_front1.filename} --private-key ${local_sensitive_file.private_key.filename} frontend.yaml"
  }
}

output "virtual_machine_ip_front1" {
  value = azurerm_public_ip.public_ip_front1.ip_address
}