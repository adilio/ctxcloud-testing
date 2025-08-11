provider "aws" {
  region = var.aws_region
}

# Get the oldest available Windows Server 2019 AMI for the chosen region
data "aws_ami" "oldest_windows" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "sg" {
  name        = "${var.lab_scenario}-sg"
  description = "Security Group for ${var.lab_scenario}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks      = [var.allow_rdp_cidr]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    owner    = var.resource_owner
    scenario = var.lab_scenario
  }
}

resource "aws_vpc" "scenario_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    owner    = var.owner
    scenario = var.scenario
  }
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

data "aws_vpc" "default" {
  id = aws_vpc.scenario_vpc.id
}

resource "aws_instance" "this" {
  subnet_id                   = aws_subnet.scenario_subnet.id
  key_name                    = var.key_name
  ami                         = data.aws_ami.oldest_windows.id
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.sg.id]
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "optional" # IMDSv1 allowed
  }

  root_block_device {
    encrypted = false
  }

  user_data = file("${path.module}/user_data.ps1")

  tags = {
    Name     = "${var.owner}-${var.lab_scenario}"
    owner    = var.resource_owner
    scenario = var.lab_scenario
  }
}

output "public_ip" {
  value = aws_instance.this.public_ip
}

output "public_dns" {
  value = aws_instance.this.public_dns
}
# Add Internet Gateway and public route for RDP access
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.scenario_vpc.id
  tags = {
    Name = "${var.owner}-${var.scenario}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.scenario_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = {
    Name = "${var.owner}-${var.scenario}-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.scenario_subnet.id
  route_table_id = aws_route_table.public.id
}