terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key for EC2 access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

resource "aws_key_pair" "docker_key" {
  key_name   = "${var.lab_scenario}-key"
  public_key = file(var.ssh_public_key_path)
}

resource "aws_security_group" "docker_sg" {
  name        = "${var.lab_scenario}-sg"
  description = "Allow SSH and app port"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allow_ssh_cidr]
  }

  ingress {
    description = "App port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allow_app_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Owner    = var.owner
    Scenario = var.lab_scenario
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "docker_host" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.docker_key.key_name
  vpc_security_group_ids      = [aws_security_group.docker_sg.id]
  subnet_id                   = element(data.aws_subnet_ids.default.ids, 0)
  associate_public_ip_address = true
  user_data                   = file("${path.module}/user_data.sh")

  metadata_options {
    http_tokens = "optional" # Enable IMDSv1 for risk
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp2"
    encrypted             = false
    delete_on_termination = true
  }

  tags = {
    Owner    = var.owner
    Scenario = var.lab_scenario
  }
}

output "public_ip" {
  value = aws_instance.docker_host.public_ip
}

output "app_url" {
  value = "http://${aws_instance.docker_host.public_ip}:8080"
}