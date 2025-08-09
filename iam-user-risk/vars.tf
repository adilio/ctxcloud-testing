variable "owner" {
  description = "Owner tag for all resources"
  type        = string
  default     = "aleghari"
}

variable "region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "scenario" {
  description = "Scenario name for tagging"
  type        = string
  default     = "iam-user-risk"
}

variable "iam_user_name" {
  description = "Name of the IAM user to create"
  type        = string
  default     = "iam-lab-user"
}