# existing key pair name to be assigned to EC2 instance
aws_key_name = "id_rsa"
# local path of pem file for SSH connection - local_key_path/aws_key_name.pem
local_key_path = "~/.ssh"


# Optional
member_count = "2"

aws_instance_type      = "t2.micro"
aws_region             = "us-east-1"
aws_tag_key            = "Category"
aws_tag_value          = "hazelcast-aws-discovery"
aws_connection_retries = "3"

hazelcast_version     = "4.0"
hazelcast_aws_version = "3.1"
hazelcast_mancenter_version = "4.2020.08"