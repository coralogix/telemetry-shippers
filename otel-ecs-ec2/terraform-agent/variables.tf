variable "ecs_cluster_name" {
  description = "Name of the AWS ECS Cluster to deploy the Coralogix OTEL Collector. Supports Amazon EC2 instances only, not Fargate."
  type        = string
}

variable "image_version" {
  description = "The Coralogix Open Telemetry Distribution Image Version/Tag. See: https://hub.docker.com/r/coralogixrepo/coralogix-otel-collector/tags"
  type        = string
  default     = "v0.5.0"
}

variable "image" {
  description = "The OpenTelemetry Collector Image to use. Should accept default unless advised by Coralogix support."
  type        = string
  default     = "coralogixrepo/coralogix-otel-collector"
}

variable "memory" {
  description = "The amount of memory (in MiB) used by the task. Note that your cluster must have sufficient memory available to support the given value. Minimum __256__ MiB. CPU Units will be allocated directly proportional to Memory."
  type        = number
  default     = 256
}


variable "use_api_key_secret" {
  description = "Whether to use API key stored in AWS Secrets Manager"
  type        = bool
  default     = false
}

variable "api_key" {
  description = "The Send-Your-Data API key for your Coralogix account. See: https://coralogix.com/docs/send-your-data-api-key/"
  type        = string
  sensitive   = true
  default     = null
}

variable "api_key_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the API key"
  type        = string
  default     = null
}



variable "task_execution_role_arn" {
  description = "ARN of the task execution role that the Amazon ECS container agent and the Docker daemon can assume"
  type        = string
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = null
}

 


variable "health_check_enabled" {
  description = "Enable ECS container health check for the OTEL agent container, Requires OTEL collector image version v0.4.2 or later."
  type        = bool
  default     = false
}

variable "health_check_interval" {
  description = "Health check interval in seconds. Only used if health_check_enabled is true."
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds. Only used if health_check_enabled is true."
  type        = number
  default     = 5
}

variable "health_check_retries" {
  description = "Health check retries. Only used if health_check_enabled is true."
  type        = number
  default     = 3
}

variable "health_check_start_period" {
  description = "Health check start period in seconds. Only used if health_check_enabled is true."
  type        = number
  default     = 10
}

variable "aws_region" {
  description = "AWS region for the provider configuration (default: us-east-1)"
  type        = string
  default     = null
}
