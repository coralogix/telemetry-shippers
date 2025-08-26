output "coralogix_otel_agent_task_definition_arn" {
  value       = aws_ecs_task_definition.coralogix_otel_agent.arn
  description = "ARN of the ECS Task Definition for the OTEL Agent Daemon"
}

output "coralogix_otel_agent_service_id" {
  value       = aws_ecs_service.coralogix_otel_agent.id
  description = "ID of the ECS Service for the OTEL Agent Daemon"
}
