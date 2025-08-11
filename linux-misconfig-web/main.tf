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

# Lookup oldest Ubuntu 20.04 AMI in selected region
data "aws_ami_ids" "ubuntu" {
  owners = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

data "aws_ami" "oldest" {
  most_recent = false
  owners      = ["099720109477"]
  filter {
    name   = "image-id"
    values = [sort(data.aws_ami_ids.ubuntu.ids)[length(data.aws_ami_ids.ubuntu.ids)-1]]
  }
}

resource "aws_security_group" "web_sg" {
  name        = "${var.scenario}-sg"
  description = "Security group for ${var.scenario}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks      = [var.allow_ssh_cidr]
    ipv6_cidr_blocks = [var.allow_ssh_cidr_ipv6]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allow_http_cidr]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allow_http_cidr]
  }
  
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    owner    = var.owner
    scenario = var.scenario
  }
}

resource "aws_vpc" "scenario_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    owner    = var.owner
    scenario = var.scenario
  }
}

resource "aws_internet_gateway" "scenario_igw" {
  vpc_id = aws_vpc.scenario_vpc.id
  tags = {
    owner    = var.owner
    scenario = var.scenario
  }
}

resource "aws_route_table" "scenario_rt" {
  vpc_id = aws_vpc.scenario_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.scenario_igw.id
  }
  tags = {
    owner    = var.owner
    scenario = var.scenario
  }
}

resource "aws_route_table_association" "scenario_rta" {
  subnet_id      = aws_subnet.scenario_subnet.id
  route_table_id = aws_route_table.scenario_rt.id
}

data "aws_vpc" "default" {
  id = aws_vpc.scenario_vpc.id
}

resource "aws_subnet" "scenario_subnet" {
  vpc_id                  = aws_vpc.scenario_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    owner    = var.owner
    scenario = var.scenario
  }
}

resource "aws_instance" "linux_web" {
  ami                         = data.aws_ami.oldest.id
  instance_type               = "t3.medium"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web_sg.id]

  key_name                    = var.key_name
  subnet_id                   = aws_subnet.scenario_subnet.id
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional" # Enables IMDSv1
  }

  root_block_device {
    encrypted = false
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    SCENARIO_NAME = var.scenario
    DUMMY_API_KEY = var.dummy_api_key
    STRIPE_KEY    = var.stripe_key
    AWS_KEY       = var.aws_key
    GITHUB_TOKEN  = var.github_token
  })

  tags = {
    Name     = "${var.owner}-${var.scenario}"
    owner    = var.owner
    scenario = var.scenario
  }
}
