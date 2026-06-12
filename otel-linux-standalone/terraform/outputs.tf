output "instance_id" {
  description = "ID of the created EC2 instance."
  value       = aws_instance.otel.id
}

output "public_ip" {
  description = "Public IP address of the EC2 instance."
  value       = aws_instance.otel.public_ip
}

output "ssh_command" {
  description = "Convenience SSH command."
  value       = "ssh -i ${var.ssh_private_key_path} ubuntu@${aws_instance.otel.public_ip}"
}

output "systemd_check_command" {
  description = "Command to verify the collector service status over SSH."
  value       = "sudo systemctl status otelcol-contrib.service --no-pager"
}

output "journal_tail_command" {
  description = "Command to tail the collector logs over SSH."
  value       = "sudo journalctl -u otelcol-contrib.service -f"
}
