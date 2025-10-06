output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group providing cluster capacity"
  value       = aws_autoscaling_group.ecs.name
}
