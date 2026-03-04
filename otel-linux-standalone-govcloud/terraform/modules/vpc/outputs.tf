output "vpc_id" {
  description = "ID of the created VPC. Pass this to the root module's vpc_id variable."
  value       = aws_vpc.this.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets. Pass the first element (or preferred subnet) to the root module's subnet_id variable."
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (empty when enable_nat_gateway is false)."
  value       = aws_subnet.public[*].id
}

output "nat_gateway_id" {
  description = "ID of the NAT gateway (empty when enable_nat_gateway is false)."
  value       = var.enable_nat_gateway ? aws_nat_gateway.this[0].id : null
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT gateway. Allowlist this on any firewall rules protecting coralogixgov.com ingestion endpoints."
  value       = var.enable_nat_gateway ? aws_eip.nat[0].public_ip : null
}

output "flow_log_group_name" {
  description = "CloudWatch log group name for VPC flow logs (empty when enable_flow_logs is false)."
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}
