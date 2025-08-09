output "public_ip" {
  description = "Public IP of the instance"
  value       = aws_instance.linux_web.public_ip
}

output "public_dns" {
  description = "Public DNS of the instance"
  value       = aws_instance.linux_web.public_dns
}

output "security_group_id" {
  description = "Security Group ID"
  value       = aws_security_group.web_sg.id
}
