terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 2.23.0"
    }
  }
  required_version = ">= 0.13"
}

# Configure the Microsoft Azure Provider.
provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}_rg"
  location = var.location
}

# Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}_vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IP(s)
resource "azurerm_public_ip" "publicip" {
  count               = var.member_count + 1
  name                = "${var.prefix}_publicip_${count.index}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}



# Create user assigned managed identity
resource "azurerm_user_assigned_identity" "hazelcast_reader" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  name                = "${var.prefix}_reader_identity"
}


resource "azurerm_role_definition" "reader" {
  name  = "${var.prefix}_reader_role_definition"
  scope = data.azurerm_subscription.primary.id

  permissions {
    actions = ["Microsoft.Network/networkInterfaces/Read",
      "Microsoft.Network/publicIPAddresses/Read",
    ]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.primary.id
  ]
}

data "azurerm_subscription" "primary" {}


#Assign role to the user assigned managed identity
resource "azurerm_role_assignment" "reader" {
  scope              = data.azurerm_subscription.primary.id
  principal_id       = azurerm_user_assigned_identity.hazelcast_reader.principal_id
  role_definition_id = azurerm_role_definition.reader.id
}

# Create network interface(s)
resource "azurerm_network_interface" "nic" {
  count               = var.member_count + 1
  name                = "${var.prefix}_nic_${count.index}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    "${var.azure_tag_key}" = var.azure_tag_value
  }


  ip_configuration {
    name                          = "${var.prefix}_nicconfig_${count.index}"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.${count.index + 10}"
    public_ip_address_id          = azurerm_public_ip.publicip[count.index].id
  }
}

# Create Hazelcast member instances
resource "azurerm_linux_virtual_machine" "hazelcast_member" {
  count                 = var.member_count
  name                  = "${var.prefix}-member-${count.index}"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
  size                  = var.azure_instance_type
  admin_username        = var.azure_ssh_user

  os_disk {
    name                 = "OsDisk_${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = var.azure_ssh_user
    public_key = file("${var.local_key_path}/${var.azure_key_name}.pub")
  }


  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }


  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.hazelcast_reader.id]
  }


  connection {
    host        = azurerm_public_ip.publicip[count.index].ip_address
    user        = var.azure_ssh_user
    type        = "ssh"
    private_key = file("${var.local_key_path}/${var.azure_key_name}")
    timeout     = "60"
    agent       = false
  }

  provisioner "file" {
    source      = "scripts/start_azure_hazelcast_member.sh"
    destination = "/home/${var.azure_ssh_user}/start_azure_hazelcast_member.sh"
  }

  provisioner "file" {
    source      = "hazelcast.yaml"
    destination = "/home/${var.azure_ssh_user}/hazelcast.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "wget -qO - https://bintray.com/user/downloadSubjectPublicKey?username=hazelcast | sudo apt-key add -",
      "echo \"deb http://dl.bintray.com/hazelcast/deb stable main\" | sudo tee -a /etc/apt/sources.list",
      "sudo apt update && sudo apt -y install hazelcast",
      "sleep 10"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "cd /home/${var.azure_ssh_user}",
      "chmod 0755 start_azure_hazelcast_member.sh",
      "./start_azure_hazelcast_member.sh ${var.azure_tag_key} ${var.azure_tag_value}",
      "sleep 10",
      "tail -n 10 /home/${var.azure_ssh_user}/hazelcast.stdout.log"
    ]
  }

}

# Create Hazelcast Management Center
resource "azurerm_linux_virtual_machine" "hazelcast_mancenter" {
  name                  = "${var.prefix}-mancenter"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic[var.member_count].id]
  size                  = "Standard_B1ms"
  admin_username        = var.azure_ssh_user

  os_disk {
    name                 = "OsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = var.azure_ssh_user
    public_key = file("${var.local_key_path}/${var.azure_key_name}.pub")
  }


  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }


  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.hazelcast_reader.id]
  }


  connection {
    host        = azurerm_public_ip.publicip[var.member_count].ip_address
    user        = var.azure_ssh_user
    type        = "ssh"
    private_key = file("${var.local_key_path}/${var.azure_key_name}")
    timeout     = "60"
    agent       = false
  }

  provisioner "file" {
    source      = "scripts/start_azure_hazelcast_management_center.sh"
    destination = "/home/${var.azure_ssh_user}/start_azure_hazelcast_management_center.sh"
  }

  provisioner "file" {
    source      = "hazelcast-client.yaml"
    destination = "/home/${var.azure_ssh_user}/hazelcast-client.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo apt-get update",
      "sudo apt-get -y install openjdk-8-jdk wget unzip",
      "sleep 10"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "cd /home/${var.azure_ssh_user}",
      "chmod 0755 start_azure_hazelcast_management_center.sh",
      "./start_azure_hazelcast_management_center.sh ${var.hazelcast_mancenter_version} ${var.azure_tag_key} ${var.azure_tag_value}",
      "sleep 30",
      "tail -n 10 ./logs/mancenter.stdout.log"
    ]
  }

}
