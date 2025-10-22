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
  description = "EC2 instance type for ECS capacity"
  type        = string
  default     = "t3.micro"
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

variable "tags" {
  description = "Base tags applied to supported resources"
  type        = map(string)
  default     = {}
}

variable "image" {
  description = "OpenTelemetry Collector image repository"
  type        = string
  default     = "coralogixrepo/coralogix-otel-collector"
}

variable "image_version" {
  description = "OpenTelemetry Collector image tag"
  type        = string
  default     = "v0.5.2"
}

variable "memory" {
  description = "Memory (MiB) assigned to the OTEL agent task"
  type        = number
  default     = 256
}

variable "task_execution_role_arn" {
  description = "ARN of the task execution role for the OTEL agent"
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

variable "telemetrygen_image" {
  description = "Telemetrygen image to run"
  type        = string
  default     = "ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest"
}

variable "rate_per_second" {
  description = "Number of traces sent each second"
  type        = number
  default     = 10
}

variable "duration" {
  description = "Telemetry generation duration (e.g. 60s, 5m)"
  type        = string
  default     = "60s"
}

variable "desired_count" {
  description = "Desired number of telemetry generator tasks"
  type        = number
  default     = 1
}

variable "otel_endpoint" {
  description = "OTLP gRPC endpoint for telemetrygen to send to"
  type        = string
  default     = "localhost:4317"
}

variable "otel_insecure" {
  description = "Use insecure OTLP when sending telemetry"
  type        = bool
  default     = true
}

variable "task_cpu" {
  description = "CPU units for the telemetry generator task"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memory (MiB) for the telemetry generator task"
  type        = number
  default     = 256
}
