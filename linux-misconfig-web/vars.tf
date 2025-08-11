variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "owner" {
  description = "Owner tag"
  type        = string
  default     = "aleghari"
}

variable "scenario" {
  description = "Scenario name"
  type        = string
  default     = "linux-misconfig-web"
}

variable "allow_ssh_cidr" {
  description = "CIDR block for SSH access (IPv4)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "allow_ssh_cidr_ipv6" {
  description = "CIDR block for SSH access (IPv6)"
  type        = string
  default     = "::/0"
}

variable "stripe_key" {
  description = "Fake Stripe key for CSPM trigger"
  type        = string
  default     = "sk_live_placeholder"
}

variable "aws_key" {
  description = "Fake AWS Access Key ID for CSPM trigger"
  type        = string
  default     = "AKIA_PLACEHOLDER"
}

variable "github_token" {
  description = "Fake GitHub token for CSPM trigger"
  type        = string
  default     = "ghp_placeholder"
}

variable "allow_http_cidr" {
  description = "CIDR block for HTTP/HTTPS access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "key_name" {
  description = "Name of an existing EC2 Key Pair"
  type        = string
}

variable "dummy_api_key" {
  description = "Fake API key to deploy as a canary"
  type        = string
  default     = "sk_live_51H6kP7kYbQe9Lm3e8xT7wzAq5b6Vn"
}

variable "aws_region" {
  description = "AWS region where resources are created"
  type        = string
  default     = "us-east-1"
}

