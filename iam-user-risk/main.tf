provider "aws" {
  region = var.region
}

resource "aws_iam_user" "this" {
  name = var.iam_user_name
  tags = {
    owner    = var.owner
    scenario = var.scenario
  }
}

# Create two access keys for the IAM user
resource "aws_iam_access_key" "key1" {
  user = aws_iam_user.this.name
}

resource "aws_iam_access_key" "key2" {
  user = aws_iam_user.this.name
}

# Broad inline policy (overly permissive for simulation purposes)
resource "aws_iam_user_policy" "broad_policy" {
  name = "${var.iam_user_name}-broad-policy"
  user = aws_iam_user.this.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

# (Optional) Weak account password policy for demo (allows short passwords, no character requirements)
resource "aws_iam_account_password_policy" "weak_policy" {
  minimum_password_length        = 6
  require_lowercase_characters   = false
  require_uppercase_characters   = false
  require_numbers                = false
  require_symbols                = false
  allow_users_to_change_password = true
}

output "iam_user_name" {
  value = aws_iam_user.this.name
}

output "access_key_1" {
  value     = aws_iam_access_key.key1.id
  sensitive = true
}

output "secret_key_1" {
  value     = aws_iam_access_key.key1.secret
  sensitive = true
}

output "access_key_2" {
  value     = aws_iam_access_key.key2.id
  sensitive = true
}

output "secret_key_2" {
  value     = aws_iam_access_key.key2.secret
  sensitive = true
}