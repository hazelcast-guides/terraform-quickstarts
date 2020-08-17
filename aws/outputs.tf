output "public_ip" {
  value       = aws_instance.hazelcast_member.*.public_ip
  description = "The public IP of the Hazelcast Member"
}
