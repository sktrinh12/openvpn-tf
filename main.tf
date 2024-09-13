resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "openvpn_key" {
  key_name   = "${var.key_name}_ec2_key"
  public_key = tls_private_key.private_key.public_key_openssh
}

resource "local_file" "ssh_private_key" {
  filename = "${path.module}/openvpn_key.pem"
  content  = tls_private_key.private_key.private_key_pem
  file_permission = "0600"
}

resource "aws_instance" "openvpn" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.openvpn_key.key_name

  tags = {
    Name = "OpenVPN-Server"
  }

  provisioner "file" {
    source      = "config/${var.script_file}"
    destination = "/tmp/${var.script_file}"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.private_key.private_key_pem
      host        = self.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/${var.script_file}",
      "echo ${aws_instance.openvpn.public_ip} > /home/ubuntu/ip_addr",
      "sudo /tmp/${var.script_file}"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.private_key.private_key_pem
      host        = self.public_ip
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  security_groups = [aws_security_group.sg_openvpn.name]
}

resource "aws_security_group" "sg_openvpn" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
