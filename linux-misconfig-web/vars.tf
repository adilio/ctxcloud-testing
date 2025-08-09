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
  description = "CIDR block for SSH access"
  type        = string
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
