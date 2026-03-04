output "instance_id" {
  description = "ID of the created EC2 instance."
  value       = aws_instance.otel.id
}

output "private_ip" {
  description = "Private IP address of the EC2 instance."
  value       = aws_instance.otel.private_ip
}

output "public_ip" {
  description = "Public IP address of the EC2 instance (empty when associate_public_ip_address is false)."
  value       = aws_instance.otel.public_ip
}

output "iam_role_arn" {
  description = "ARN of the IAM role attached to the instance."
  value       = aws_iam_role.otel.arn
}

output "ssh_command" {
  description = "SSH command to connect to the instance (only useful when a public IP and key pair are configured)."
  value       = local.create_key_pair ? "ssh -i ${var.ssh_private_key_path} ubuntu@${aws_instance.otel.public_ip}" : "No key pair configured — use SSM Session Manager: aws ssm start-session --target ${aws_instance.otel.id} --region ${var.aws_region}"
}

output "ssm_session_command" {
  description = "SSM Session Manager command to open a shell on the instance."
  value       = "aws ssm start-session --target ${aws_instance.otel.id} --region ${var.aws_region}"
}

output "systemd_check_command" {
  description = "Command to verify the collector service status."
  value       = "sudo systemctl status otelcol-contrib.service --no-pager"
}

output "journal_tail_command" {
  description = "Command to tail the collector logs."
  value       = "sudo journalctl -u otelcol-contrib.service -f"
}
