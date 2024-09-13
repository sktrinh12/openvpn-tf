output "instance_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.openvpn.public_ip
}

output "private_key_pem" {
  value = tls_private_key.private_key.private_key_pem
  sensitive = true
}
