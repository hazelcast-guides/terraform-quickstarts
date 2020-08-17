
# Configure the Microsoft Azure Provider.
provider "azurerm" {
  version = "2.1.0"
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}_RG"
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
  address_prefix       = "10.0.1.0/24"
}

# Create public IP(s)
resource "azurerm_public_ip" "publicip" {
  count               = var.member_count
  name                = "${var.prefix}_publicip_${count.index}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}


data "azurerm_subscription" "primary" {}

# Create user assigned managed identity
resource "azurerm_user_assigned_identity" "hazelcast_reader" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  name                = "${var.prefix}_reader"
}


# resource "azurerm_role_definition" "reader" {
#   name               = "reader-role"
#   scope              = data.azurerm_subscription.primary.id

#   permissions {
#     actions     = ["Microsoft.Network/virtualNetworks/Read"]
#     not_actions = []
#   }

#   assignable_scopes = [
#    data.azurerm_subscription.primary.id
#   ]
# }


#Assign role to the user assigned managed identity
resource "azurerm_role_assignment" "reader" {
  scope                = data.azurerm_subscription.primary.id
  principal_id         = azurerm_user_assigned_identity.hazelcast_reader.principal_id
  role_definition_name = "Reader"
  #role_definition_id    = azurerm_role_definition.reader.id
}

# Create network interface(s)
resource "azurerm_network_interface" "nic" {
  count               = var.member_count
  name                = "${var.prefix}_nic_${count.index}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "${var.prefix}_nicconfig_${count.index}"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.${count.index + 5}"
    public_ip_address_id          = azurerm_public_ip.publicip[count.index].id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "${var.prefix}hazelcast${count.index}1"
  count                  =var.member_count
  location             = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
  size                  = "Standard_F2"
  admin_username        = var.username
  computer_name         = "${var.prefix}Member${count.index}"
  
  tags                  = var.tags

  os_disk {
    name                 = "OsDisk_${count.index}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  admin_ssh_key {
    username   = var.username
    public_key = file("~/.ssh/id_rsa.pub")
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


}

resource "null_resource" "provisioning_vms" {
    count = var.member_count
    depends_on = [
      azurerm_linux_virtual_machine.vm
    ]
    connection {
      host        = azurerm_public_ip.publicip[count.index].ip_address
      user        = var.username
      type        = "ssh"
      private_key = file("~/.ssh/id_rsa")
      timeout     = "30s"
      agent       = false
    }

    provisioner "remote-exec" {
      inline = [
        "mkdir -p /home/${var.username}/jars",
        "mkdir -p /home/${var.username}/logs",
        "sudo apt-get update",
        "sudo apt-get -y install openjdk-8-jdk wget",
        "sleep 30"
      ]
    }

    provisioner "file" {
        source      = "~/hz/hazelcast-4.1-SNAPSHOT.jar"
        destination = "/home/${var.username}/jars/hazelcast-4.1-SNAPSHOT.jar"
    }


    provisioner "file" {
        source      = "~/hz/hazelcast-azure.jar"
        destination = "/home/${var.username}/jars/hazelcast-azure.jar"
    }


    provisioner "remote-exec" {
      inline = [
        "java -cp /home/${var.username}/jars/hazelcast-4.1-SNAPSHOT.jar:/home/${var.username}/jars/hazelcast-azure.jar -server com.hazelcast.core.server.HazelcastMemberStarter >> /home/${var.username}/logs/hazelcast.stderr.log 2>> /home/${var.username}/logs/hazelcast.stdout.log &",
        "sleep 30",
        "tail -n 10 /home/${var.username}/logs/hazelcast.stdout.log",
        # "curl -H 'Metadata: True' http://169.254.169.254/metadata/instance?api-version=2020-06-01",
        # "cat /etc/resolv.conf"
      ]
    }
}
resource "null_resource" "run_exec999" {
    count = var.member_count
    depends_on = [
      azurerm_linux_virtual_machine.vm
    ]
    connection {
      host        = azurerm_public_ip.publicip[count.index].ip_address
      user        = var.username
      type        = "ssh"
      private_key = file("~/.ssh/id_rsa")
      timeout     = "30s"
      agent       = false
    }

      provisioner "file" {
        source      = "~/hz/hazelcast-azure.jar"
        destination = "/home/${var.username}/jars/hazelcast-azure.jar"
    }

    provisioner "remote-exec" {
      inline = [
        "rm -rf /home/${var.username}/logs",
        "mkdir -p /home/${var.username}/logs",
        "java -cp /home/${var.username}/jars/hazelcast-4.1-SNAPSHOT.jar:/home/${var.username}/jars/hazelcast-azure.jar -server com.hazelcast.core.server.HazelcastMemberStarter >> /home/${var.username}/logs/hazelcast.stderr.log 2>> /home/${var.username}/logs/hazelcast.stdout.log &",
        "sleep 30",
        "tail -n 10 /home/${var.username}/logs/hazelcast.stdout.log",
        # "curl -H 'Metadata: True' http://169.254.169.254/metadata/instance?api-version=2020-06-01",
        # "cat /etc/resolv.conf"
      ]
    }
}



# resource "null_resource" "run_exec2" {
#     count = var.member_count
#     depends_on = [
#       azurerm_linux_virtual_machine.vm
#     ]
#     connection {
#       host        = azurerm_public_ip.publicip[count.index].ip_address
#       user        = var.username
#       type        = "ssh"
#       private_key = file("~/.ssh/id_rsa")
#       timeout     = "30s"
#       agent       = false
#     }


#     provisioner "remote-exec" {
#       inline = [
#         "rm /home/ubuntu/logs/hazelcast.stdout.log",
#         "rm /home/ubuntu/logs/hazelcast.stderr.log",
#         "nohup java -cp /home/${var.username}/jars/hazelcast-4.1-SNAPSHOT.jar:/home/${var.username}/jars/hazelcast-azure.jar -server com.hazelcast.core.server.HazelcastMemberStarter >> /home/${var.username}/logs/hazelcast.stderr.log 2>> /home/${var.username}/logs/hazelcast.stdout.log &",
#         "sleep 30",
#         "tail -n 10 /home/${var.username}/logs/hazelcast.stdout.log" ,
#         "curl -H 'Metadata: True' http://169.254.169.254/metadata/instance?api-version=2020-06-01",
#         "cat /etc/resolv.conf"
#       ]
#     }
# }


  # provisioner "file" {
  #   source      = "scripts/start_azure_hazelcast_member.sh"
  #   destination = "/home/${var.username}/start_azure_hazelcast_member.sh"
  # }

  # provisioner "file" {
  #   source      = "hazelcast.yaml"
  #   destination = "/home/${var.username}/hazelcast.yaml"
  # }

  # provisioner "remote-exec" {
  #   inline = [
  #     "sudo apt-get update",
  #     "sudo apt-get -y install openjdk-8-jdk wget",
  #     "sleep 30"
  #   ]
  # }

  # provisioner "remote-exec" {
  #   inline = [
  #     "cd /home/${var.username}",
  #     "chmod 0755 start_azure_hazelcast_member.sh",
  #     "./start_azure_hazelcast_member.sh ${var.hazelcast_version} ${var.hazelcast_azure_version} tag-name=hazelcast",
  #     "sleep 30",
  #     "tail -n 10 ./logs/hazelcast.stdout.log"
  #   ]
  # }


