output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.supervisor.arn
}

output "task_definition_family" {
  description = "Family name of the ECS task definition"
  value       = aws_ecs_task_definition.supervisor.family
}

output "service_arn" {
  description = "ARN of the ECS service (if created)"
  value       = var.create_service ? aws_ecs_service.supervisor[0].id : null
}

output "service_name" {
  description = "Name of the ECS service (if created)"
  value       = var.create_service ? aws_ecs_service.supervisor[0].name : null
}

output "execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.task.arn
}

output "security_group_id" {
  description = "ID of the security group (if created)"
  value       = var.launch_type == "FARGATE" && var.security_group_id == "" ? aws_security_group.supervisor[0].id : var.security_group_id
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.supervisor.name
}

output "coralogix_private_key_parameter_arn" {
  description = "ARN of the SSM parameter containing Coralogix private key (if created)"
  value       = var.coralogix_private_key != "" ? aws_ssm_parameter.coralogix_private_key[0].arn : null
  sensitive   = true
}

output "ecs_cluster_id" {
  description = "ID of the ECS cluster used by the supervisor"
  value       = var.create_ecs_cluster ? aws_ecs_cluster.supervisor[0].id : var.ecs_cluster_id
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster (if created by this module)"
  value       = var.create_ecs_cluster ? aws_ecs_cluster.supervisor[0].arn : null
}
