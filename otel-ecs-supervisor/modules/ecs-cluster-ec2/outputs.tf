output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.this.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "capacity_provider_name" {
  description = "Name of the ECS capacity provider when created"
  value       = var.enable_capacity ? aws_ecs_capacity_provider.this[0].name : null
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group backing the capacity provider"
  value       = var.enable_capacity ? aws_autoscaling_group.ecs[0].arn : null
}

output "instance_security_group_id" {
  description = "Security group ID for the ECS container instances"
  value       = var.enable_capacity ? aws_security_group.ecs_instances[0].id : null
}
