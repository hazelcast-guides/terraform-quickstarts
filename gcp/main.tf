provider "google" {
  version = "3.5.0"

  credentials = file("auth.json")
  batching {
    enable_batching = "false"
  }
  project = var.project-id
  region  = var.region
  zone    = var.zone
}




#COMMON NETWORK - SUBNETWORK - FIREWALL

resource "google_compute_network" "vpc_common_network" {
  name                    = "terraform-common-network"
  auto_create_subnetworks = false
}


resource "google_compute_subnetwork" "vpc_common_subnetwork" {
  name          = "terraform-common-subnetwork"
  ip_cidr_range = "10.0.10.0/24"
  region        = var.region
  network       = google_compute_network.vpc_common_network.id
}

resource "google_compute_firewall" "common" {
  name    = "ssh-common-firewall"
  network = google_compute_network.vpc_common_network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "5701-5707"]
  }

  allow {
    protocol = "icmp"
  }
}


# PER INSTANCE NETWORK

# resource "google_compute_network" "vpc_network" {
#   count                   = var.member_count
#   name                    = "terraform-network-${count.index}"
#   auto_create_subnetworks = false
# }

# resource "google_compute_subnetwork" "vpc_subnetwork" {
#   count         = var.member_count
#   name          = "terraform-subnetwork-${count.index}"
#   ip_cidr_range = "10.0.${count.index + 1}.0/24"
#   region        = var.region
#   network       = google_compute_network.vpc_network[count.index].id
# }

# resource "google_compute_firewall" "per_instance" {
#   count   = var.member_count
#   name    = "ssh-firewall-${count.index}"
#   network = google_compute_network.vpc_network[count.index].name

#   allow {
#     protocol = "tcp"
#     ports    = ["22", "5701-5707"]
#   }

#   allow {
#     protocol = "icmp"
#   }
# }

resource "google_compute_address" "vm_static_ip" {
  count = var.member_count
  name  = "terraform-static-ip${count.index}"
}

resource "google_compute_instance" "hazelcast_vm" {
  count                     = var.member_count
  name                      = "hazelcast-instance-${count.index}-test"
  machine_type              = "f1-micro"
  hostname                  = "hazelcast-instance-${count.index}-test.com"
  allow_stopping_for_update = "true"
  zone                      = var.zone
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vpc_common_subnetwork.self_link
    access_config {
      nat_ip = google_compute_address.vm_static_ip[count.index].address
    }
  }

  # network_interface {
  #   subnetwork = google_compute_subnetwork.vpc_subnetwork[count.index].self_link
  # }

   service_account {
    email = "tester@boxwood-veld-282011.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "${var.gce_ssh_user}:${file(var.gce_ssh_pub_key_file)}"
  }

}


resource "null_resource" "provisioning_vms" {
    count = var.member_count
    depends_on = [
      google_compute_instance.hazelcast_vm
    ]
    connection {
      host        = google_compute_instance.hazelcast_vm[count.index].network_interface.0.access_config.0.nat_ip
      user        = var.gce_ssh_user
      type        = "ssh"
      private_key = file("~/.ssh/id_rsa")
      timeout     = "30s"
      agent       = false
    }

    provisioner "remote-exec" {
      inline = [
        "mkdir -p /home/ubuntu/jars",
        "mkdir -p /home/ubuntu/logs",
        "sudo apt-get update",
        "sudo apt-get -y install openjdk-8-jdk wget",
        "sleep 30"
      ]
    }

    provisioner "file" {
        source      = "~/hz/hazelcast-4.1-SNAPSHOT.jar"
        destination = "/home/${var.gce_ssh_user}/jars/hazelcast-4.1-SNAPSHOT.jar"
    }


    provisioner "file" {
        source      = "~/hz/hazelcast-gcp.jar"
        destination = "/home/${var.gce_ssh_user}/jars/hazelcast-gcp.jar"
    }


    provisioner "remote-exec" {
      inline = [
        "java -cp /home/ubuntu/jars/hazelcast-4.1-SNAPSHOT.jar:/home/ubuntu/jars/hazelcast-gcp.jar -server com.hazelcast.core.server.HazelcastMemberStarter >> /home/ubuntu/logs/hazelcast.stderr.log 2>> /home/ubuntu/logs/hazelcast.stdout.log &",
        "sleep 30",
         "tail -n 10 /home/ubuntu/logs/hazelcast.stdout.log" ,
        # "curl -H 'Metadata-Flavor: Google' metadata.google.internal/computeMetadata/v1/instance/service-accounts/"
      ]
    }
}

# resource "null_resource" "run_exec2" {
#     count = var.member_count
#     depends_on = [
#       google_compute_instance.hazelcast_vm
#     ]

#       connection {
#       host        = google_compute_instance.hazelcast_vm[count.index].network_interface.0.access_config.0.nat_ip
#       user        = var.gce_ssh_user
#       type        = "ssh"
#       private_key = file("~/.ssh/id_rsa")
#       timeout     = "35s"
#       agent       = false
#     }

#     provisioner "remote-exec" {
#       inline = [
#         "rm /home/ubuntu/logs/hazelcast.stdout.log",
#         "rm /home/ubuntu/logs/hazelcast.stderr.log",
#         "java -cp /home/ubuntu/jars/hazelcast-4.1-SNAPSHOT.jar:/home/ubuntu/jars/hazelcast-gcp.jar -server com.hazelcast.core.server.HazelcastMemberStarter >> /home/ubuntu/logs/hazelcast.stderr.log 2>> /home/ubuntu/logs/hazelcast.stdout.log &",
#         "sleep 35",
#         "tail -n 10 ./logs/hazelcast.stdout.log" ,
#         "curl -H 'Metadata-Flavor: Google' metadata.google.internal/computeMetadata/v1/instance/service-accounts/"

#       ]
#     }

# }

# resource "null_resource" "hazelcast" {
#   count = var.member_count
#   depends_on = [
#     google_compute_instance.hazelcast_vm
#   ]
#   connection {
#     host        = google_compute_instance.hazelcast_vm[count.index].network_interface.0.access_config.0.nat_ip
#     user        = var.gce_ssh_user
#     type        = "ssh"
#     private_key = file("~/.ssh/id_rsa")
#     timeout     = "30s"
#     agent       = false
#   }
#   provisioner "file" {
#     source      = "scripts/start_gcp_hazelcast_member.sh"
#     destination = "/home/${var.gce_ssh_user}/start_gcp_hazelcast_member.sh"
#   }

#   provisioner "file" {
#     source      = "hazelcast.yaml"
#     destination = "/home/${var.gce_ssh_user}/hazelcast.yaml"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "sudo apt-get update",
#       "sudo apt-get -y install openjdk-8-jdk wget",
#       "sleep 20"
#     ]
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "cd /home/${var.gce_ssh_user}",
#       "chmod 0755 start_gcp_hazelcast_member.sh",
#       "./start_gcp_hazelcast_member.sh ${var.hazelcast_version} ${var.hazelcast_gcp_version} tag-name=hazelcast",
#       "sleep 30",
#       "tail -n 10 ./logs/hazelcast.stdout.log"
#     ]
#   }
# }

