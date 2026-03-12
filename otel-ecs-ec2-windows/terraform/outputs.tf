output "ecs_cluster_arn" {
  description = "ARN of the created ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group providing ECS capacity"
  value       = aws_autoscaling_group.ecs.name
}

output "coralogix_otel_agent_task_definition_arn" {
  description = "ARN of the OTEL agent task definition"
  value       = aws_ecs_task_definition.coralogix_otel_agent.arn
}

output "coralogix_otel_agent_service_id" {
  description = "ID of the OTEL agent ECS service"
  value       = aws_ecs_service.coralogix_otel_agent.id
}

output "telemetrygen_ecr_repository_url" {
  description = "ECR repository URL for the Windows telemetrygen image. After apply, authenticate and push: aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account>.dkr.ecr.<region>.amazonaws.com; then build and push from ../telemetrygen-windows-image."
  value       = var.enable_telemetrygen ? aws_ecr_repository.telemetrygen[0].repository_url : null
}

output "telemetrygen_ecr_repository_arn" {
  description = "ARN of the ECR repository for telemetrygen"
  value       = var.enable_telemetrygen ? aws_ecr_repository.telemetrygen[0].arn : null
}
