variable "resource_owner" {
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
  default     = "windows-vuln-iis"
}

variable "allow_rdp_cidr" {
  description = "CIDR block allowed for RDP access"
  type        = string
  default     = "0.0.0.0/0"
}