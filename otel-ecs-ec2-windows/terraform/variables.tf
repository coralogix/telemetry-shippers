variable "aws_region" {
  description = "AWS region to deploy all resources into"
  type        = string
  default     = "eu-west-1"
}

variable "cluster_name" {
  description = "Name for the ECS cluster and related resources"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for Windows ECS capacity. Use t3.xlarge or larger when running both the OTEL agent and telemetrygen (separate services), so the instance has enough ENIs (4+); t3.large has only 3 ENIs and can hit 'Timeout waiting for network interface provisioning'."
  type        = string
  default     = "t3.xlarge"
}

variable "desired_capacity" {
  description = "Desired number of ECS container instances"
  type        = number
  default     = 1
}

variable "min_size" {
  description = "Minimum number of ECS container instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of ECS container instances"
  type        = number
  default     = 2
}

variable "task_cpu" {
  description = "CPU units for the OTEL agent task (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "task_memory" {
  description = "Memory (MiB) for the OTEL agent task"
  type        = number
  default     = 2048
}

variable "ecs_container_start_timeout" {
  description = "ECS agent container start timeout (e.g. 15m). Set to empty string to omit."
  type        = string
  default     = "15m"
}

variable "tags" {
  description = "Base tags applied to supported resources"
  type        = map(string)
  default     = {}
}

variable "task_execution_role_arn" {
  description = "ARN of the task execution role for the OTEL agent (pull images, CloudWatch Logs). If null, a role with ECR and logs permissions is created."
  type        = string
  default     = null
}

variable "use_api_key_secret" {
  description = "Set to true to load the Coralogix key from Secrets Manager"
  type        = bool
  default     = false
}

variable "api_key" {
  description = "Coralogix Send-Your-Data API key"
  type        = string
  sensitive   = true
  default     = null
}

variable "api_key_secret_arn" {
  description = "Secrets Manager ARN containing the Coralogix API key"
  type        = string
  default     = null
}

variable "health_check_enabled" {
  description = "Enable the OTEL agent container health check"
  type        = bool
  default     = false
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_retries" {
  description = "Number of allowed health check retries"
  type        = number
  default     = 3
}

variable "health_check_start_period" {
  description = "Grace period before health checking starts"
  type        = number
  default     = 10
}

# --- telemetrygen-windows (sidecar) ---

variable "telemetrygen_image" {
  description = "Full image URI for telemetrygen-windows (e.g. cgx.jfrog.io/coralogix-docker-images/telemetrygen-windows:0.147.0-windows2022)"
  type        = string
  default     = "cgx.jfrog.io/coralogix-docker-images/telemetrygen-windows:0.147.0-windows2022"
}

variable "telemetrygen_cpu" {
  description = "CPU units for the telemetrygen container (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "telemetrygen_memory" {
  description = "Memory (MiB) for the telemetrygen container"
  type        = number
  default     = 512
}

variable "telemetrygen_rate" {
  description = "Telemetry generation rate (e.g. spans/logs per second)"
  type        = number
  default     = 1
}

variable "telemetrygen_duration" {
  description = "Telemetrygen run duration (Go duration, e.g. 60s, 5m, 8760h for ~1 year). Use a large value like 8760h for effectively infinite."
  type        = string
  default     = "8760h"
}

variable "telemetrygen_service_name" {
  description = "Service name set in generated telemetry"
  type        = string
  default     = "telemetrygen-windows"
}

variable "telemetrygen_desired_count" {
  description = "Desired number of telemetrygen tasks (separate ECS service)"
  type        = number
  default     = 1
}
