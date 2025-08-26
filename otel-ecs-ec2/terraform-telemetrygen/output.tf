output "telemetrygen_task_definition_arn" {
  value       = aws_ecs_task_definition.telemetrygen.arn
  description = "ARN of the telemetrygen ECS Task Definition"
}

output "telemetrygen_service_id" {
  value       = aws_ecs_service.telemetrygen.id
  description = "ID of the telemetrygen ECS Service"
}


