variable "ecs_cluster_name" {
  description = "Name or ARN of the existing AWS ECS EC2 cluster where telemetrygen will run."
  type        = string
}

variable "aws_region" {
  description = "AWS region for the provider configuration (default: eu-west-1)"
  type        = string
  default     = null
}

variable "telemetrygen_image" {
  description = "Telemetrygen image to use."
  type        = string
  default     = "ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest"
}

variable "rate_per_second" {
  description = "Number of spans per second to generate."
  type        = number
  default     = 10
}

variable "duration" {
  description = "How long to run generation, e.g. 60s, 5m."
  type        = string
  default     = "60s"
}

variable "desired_count" {
  description = "Number of generator tasks to run as a service. Set to 0 to stop."
  type        = number
  default     = 1
}

variable "otel_endpoint" {
  description = "OTLP gRPC endpoint the generator should send to. For host networking with the agent listening on host 4317, use localhost:4317."
  type        = string
  default     = "localhost:4317"
}

variable "otel_insecure" {
  description = "Use insecure OTLP (no TLS)"
  type        = bool
  default     = true
}

variable "task_cpu" {
  description = "CPU units for the ECS task."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memory (MiB) for the ECS task."
  type        = number
  default     = 256
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = null
}


