terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = ">= 3.35.0"

    }
  }
  required_version = ">= 0.13"
}

provider "google" {

  credentials = file("auth.json")
  batching {
    enable_batching = "false"
  }
  project = var.project-id
  region  = var.region
  zone    = var.zone
}


#COMMON NETWORK - SUBNETWORK - FIREWALL

resource "google_compute_network" "vpc" {
  name                    = "${var.prefix}-vpc"
  auto_create_subnetworks = false
}


resource "google_compute_subnetwork" "vpc_subnet" {
  name          = "${var.prefix}-subnet"
  ip_cidr_range = "10.0.10.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_firewall" "firewall" {
  name    = "${var.prefix}-firewall"
  network = google_compute_network.vpc.name

  # Allow SSH, Hazelcast member communication and Hazelcat Management Center website
  allow {
    protocol = "tcp"
    ports    = ["22", "5701-5707","8080"]
  }

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_address" "public_ip" {
  count = var.member_count + 1
  name  = "${var.prefix}-publicip-${count.index}"
}

resource "google_compute_instance" "hazelcast_member" {
  count                     = var.member_count
  name                      = "${var.prefix}-instance-${count.index}"
  machine_type              = var.gcp_instance_type
  allow_stopping_for_update = "true"
  zone                      = var.zone
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vpc_subnet.self_link
    access_config {
      nat_ip = google_compute_address.public_ip[count.index].address
    }
  }

   service_account {
    email = "terraform-hazelcast@boxwood-veld-282011.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "${var.gce_ssh_user}:${file("${var.local_key_path}/${var.gcp_key_name}.pub")}"
  }

  connection {
    host        = self.network_interface.0.access_config.0.nat_ip
    user        = var.gce_ssh_user
    type        = "ssh"
    private_key = file("${var.local_key_path}/${var.gcp_key_name}")
    timeout     = "60s"
    agent       = false
  }
  provisioner "file" {
    source      = "scripts/start_gcp_hazelcast_member.sh"
    destination = "/home/${var.gce_ssh_user}/start_gcp_hazelcast_member.sh"
  }

  provisioner "file" {
    source      = "hazelcast.yaml"
    destination = "/home/${var.gce_ssh_user}/hazelcast.yaml"
  }

  provisioner "remote-exec" {
    inline = [
     # "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo apt-get update",
      "sudo apt-get -y install openjdk-8-jdk wget",
      "sleep 5"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "cd /home/${var.gce_ssh_user}",
      "chmod 0755 start_gcp_hazelcast_member.sh",
      "./start_gcp_hazelcast_member.sh ${var.hazelcast_version} ${var.hazelcast_gcp_version}",
      "sleep 10",
      "tail -n 10 ./logs/hazelcast.stdout.log"
    ]
  }

}


resource "google_compute_instance" "hazelcast_mancenter" {
  name                      = "hazelcast-mancenter"
  machine_type              = var.gcp_instance_type
  allow_stopping_for_update = "true"
  zone                      = var.zone
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vpc_subnet.self_link
    access_config {
      nat_ip = google_compute_address.public_ip[var.member_count].address
    }
  }

   service_account {
    email = "terraform-hazelcast@boxwood-veld-282011.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "${var.gce_ssh_user}:${file(var.gce_ssh_pub_key_file)}"
  }

  connection {
    host        = self.network_interface.0.access_config.0.nat_ip
    user        = var.gce_ssh_user
    type        = "ssh"
    private_key =  file("${var.local_key_path}/${var.gcp_key_name}")
    timeout     = "60s"
    agent       = false
  }
  provisioner "file" {
    source      = "scripts/start_gcp_hazelcast_management_center.sh"
    destination = "/home/${var.gce_ssh_user}/start_gcp_hazelcast_management_center.sh"
  }

  provisioner "file" {
    source      = "hazelcast-client.yaml"
    destination = "/home/${var.gce_ssh_user}/hazelcast-client.yaml"
  }

  provisioner "remote-exec" {
    inline = [
     # "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo apt-get update",
      "sudo apt-get -y install openjdk-8-jdk wget unzip",
      "sleep 5"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "cd /home/${var.gce_ssh_user}",
      "chmod 0755 start_gcp_hazelcast_management_center.sh",
      "./start_gcp_hazelcast_management_center.sh ${var.hazelcast_mancenter_version} ",
      "sleep 20",
      "tail -n 10 ./logs/mancenter.stdout.log"
    ]
  }

}