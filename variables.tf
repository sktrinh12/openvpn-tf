variable "ami_id" {
  description = "The AMI ID for the instance"
  default     = "ami-0e86e20dae9224db8"
}

variable "instance_type" {
  description = "The instance type for the OpenVPN server"
  default     = "t2.micro"
}

variable "key_name" {
  description = "The name of the SSH key pair"
  default     = "openvpn"
}

variable "script_file" {
  description = "The name of the bash script to run"
  default     = "openvpn-setup.sh"
}
