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
  default = "1"
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