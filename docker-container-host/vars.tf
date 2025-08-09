variable "owner" {
  description = "Owner tag for all resources"
  type        = string
  default     = "aleghari"
}

variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "lab_scenario" {
  description = "Scenario name for tagging"
  type        = string
  default     = "docker-container-host"
}

variable "allow_ssh_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string
  default     = ""
}

variable "allow_app_cidr" {
  description = "CIDR block allowed for app port (default 8080)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key for EC2 access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}