# key pair name to be assigned to EC2 instance, it will be created by terraform.
variable "azure_key_name" {
  type = string
}

# local path of private key file for SSH connection - local_key_path/azure_key_name
variable "local_key_path" {
  type = string
}

variable "location" {
  default = "central us"
}

variable "prefix" {
  default = "hazelcast"
}

variable "tags" {
  default = {
    tag-name = "hazelcast"
  }
}

variable "member_count" {
  default = "2"
}

variable "hazelcast_version" {
  default = "4.0.2"
}

variable "hazelcast_azure_version" {
  default = "2.0"
}

variable "hazelcast_mancenter_version" {
  type   = string
  default = "4.2020.08"
}

variable "azure_ssh_user" {
  default = "ubuntu"
}

variable "azure_instance_type" {
  type    = string
  default = "Standard_B1ms"
}
