# key pair name to be assigned to EC2 instance, it will be created by terraform.
variable "gcp_key_name" {
  type = string
}

# local path of private key file for SSH connection - local_key_path/aws_key_name
variable "local_key_path" {
  type = string
}

# Service account to give API access to Hazelcast members
variable "service_account_email" {
  type = string
}

variable "project_id" {
  type    = string
  default = null
}

variable "region" {
  type = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-c"
}

variable "member_count" {
  type    = number
  default = "2"
}

variable "gcp_ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "hazelcast_version" {
  type    = string
  default = "4.0.2"
}

variable "hazelcast_gcp_version" {
  type    = string
  default = "2.0.1"
}

variable "hazelcast_mancenter_version" {
  type    = string
  default = "4.2020.08"
}

variable "prefix" {
  type    = string
  default = "hazelcast"
}

variable "gcp_instance_type" {
  type    = string
  default = "f1-micro"
}


