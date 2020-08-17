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
  default = "1"
}

variable "hazelcast_version" {
  default = "4.0.2"
}

variable "hazelcast_azure_version" {
  default = "2.0"
}

variable "username" {
  default = "ubuntu"
}


variable "images"{
  default = ["Debian", "openSUSE-Leap", "RHEL", "SLES"]
}


variable "publishers"{
  default = ["credativ", "SUSE", "RedHat", "SUSE"]
}

variable "skus"{
  default = ["8","42.3","7-RAW", "12-SP2"]
}