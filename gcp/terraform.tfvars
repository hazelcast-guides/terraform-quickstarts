# key name to be assigned to Google Compute instances
gcp_key_name = #"id_rsa"

# local path of private key file for SSH connection - local_key_path/aws_key_name
local_key_path = #"~/.ssh"

# Service account to give API access to Hazelcast members
service_account_email = 

# Project ID you want to use
project_id = 


########### Optional ############

region = "us-central1"
zone   = "us-central1-c"

member_count      = "2"
gcp_instance_type = "f1-micro"

prefix                      = "hazelcast"
hazelcast_version           = "4.0.2"
hazelcast_gcp_version       = "2.0.1"
hazelcast_mancenter_version = "4.2020.08"

# Username to use when connecting to VMs
gcp_ssh_user = "ubuntu"





