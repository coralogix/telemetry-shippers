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

output "telemetrygen_task_definition_arn" {
  description = "ARN of the telemetry generator task definition"
  value       = aws_ecs_task_definition.telemetrygen.arn
}

output "telemetrygen_service_id" {
  description = "ID of the telemetry generator ECS service"
  value       = aws_ecs_service.telemetrygen.id
}
