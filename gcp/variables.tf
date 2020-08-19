# key pair name to be assigned to EC2 instance, it will be created by terraform.
variable "gcp_key_name" {
  type = string
}

# local path of private key file for SSH connection - local_key_path/aws_key_name
variable "local_key_path" {
  type = string
}

variable "project-id" {
  default = "boxwood-veld-282011"
}
variable "credentials_file" {
  default = "auth3.json"
}

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-c"
}

variable "member_count" {
  default = "2"
}

variable "gce_ssh_pub_key_file" {
  default = "~/.ssh/id_rsa.pub"
}

variable "gce_ssh_user" {
  default = "ubuntu"
}

variable "hazelcast_version" {
  default = "4.0.2"
}

variable "hazelcast_gcp_version" {
  default = "2.0.1"
}

variable "hazelcast_mancenter_version" {
  type   = string
  default = "4.2020.08"
}

variable "prefix" {
  type   = string
  default = "hazelcast"
}


variable "gcp_instance_type" {
  type    = string
  default = "f1-micro"
}
