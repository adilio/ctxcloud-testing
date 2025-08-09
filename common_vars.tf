# ============================================================
# Common Terraform Vars for All Scenarios
# This file is named 'common_vars.tf' to follow shorter, common naming patterns seen in many Terraform repos.
# Each scenario should still keep its own 'vars.tf' for modular, standalone runs.
# ============================================================

# Using lower snake_case for variable names, per Terraform conventions.

variable "owner" {
  description = "Owner tag applied to all resources"
  default     = "aleghari"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources are created"
  default     = "us-east-1"
  type        = string
}

variable "lab_scenario" {
  description = "Scenario identifier for tagging and context"
  type        = string
  default     = "default-scenario"
}