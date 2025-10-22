variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "otel-supervisor"
}

variable "coralogix_domain" {
  description = "Coralogix domain (e.g., coralogix.com, eu2.coralogix.com)"
  type        = string
  default     = "coralogix.com"
}

variable "coralogix_private_key" {
  description = "Coralogix private key (use only if not using SSM parameter or Secrets Manager)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "coralogix_private_key_ssm_parameter" {
  description = "SSM Parameter Store path containing Coralogix private key (e.g., /coralogix/private-key)"
  type        = string
  default     = ""
}

variable "coralogix_private_key_secret_arn" {
  description = "AWS Secrets Manager ARN containing Coralogix private key"
  type        = string
  default     = ""
}

variable "application_name" {
  description = "Application name for Coralogix"
  type        = string
  default     = "otel-supervisor"
}

variable "subsystem_name" {
  description = "Subsystem name for Coralogix"
  type        = string
  default     = "ecs"
}

variable "container_image" {
  description = "Container image for the supervisor"
  type        = string
  default     = "coralogixrepo/otel-supervised-collector:0.137.0"
}

variable "use_entrypoint_script" {
  description = "Use entrypoint script approach (true) or direct supervisor command (false)"
  type        = bool
  default     = false
}


variable "supervisor_config" {
  description = "Custom supervisor configuration YAML (leave empty to use default template)"
  type        = string
  default     = ""
}

variable "collector_config" {
  description = "Custom collector configuration YAML (leave empty to use default template)"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "Optional VPC ID; defaults to the AWS account's default VPC when empty."
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Optional list of subnet IDs; defaults to the default VPC subnets when empty."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.subnet_ids) == 0 || var.vpc_id != ""
    error_message = "vpc_id must be provided when supplying subnet_ids."
  }
}

variable "security_group_id" {
  description = "Existing security group ID (if empty, a new one will be created for Fargate)"
  type        = string
  default     = ""
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access OTLP ports"
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

variable "create_ecs_cluster" {
  description = "Set to true to create a dedicated ECS cluster for the supervisor"
  type        = bool
  default     = false
}

variable "ecs_cluster_name" {
  description = "Name to assign to the ECS cluster when create_ecs_cluster is true (defaults to name_prefix)"
  type        = string
  default     = ""
}

variable "ecs_cluster_id" {
  description = "ECS cluster ID/name"
  type        = string
  default     = "default"
}

variable "ecs_capacity_count" {
  description = "Number of EC2 container instances to maintain when launch_type is EC2 and the module creates the cluster"
  type        = number
  default     = 1
}

variable "launch_type" {
  description = "ECS launch type (FARGATE or EC2)"
  type        = string
  default     = "FARGATE"

  validation {
    condition     = contains(["FARGATE", "EC2"], var.launch_type)
    error_message = "Launch type must be either FARGATE or EC2."
  }
}

variable "network_mode" {
  description = "Network mode for ECS task (only applies to EC2 launch type)"
  type        = string
  default     = "bridge"
}

variable "cpu" {
  description = "CPU units for the task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory in MiB for the task"
  type        = number
  default     = 512
}

variable "cpu_architecture" {
  description = "CPU architecture (X86_64 or ARM64)"
  type        = string
  default     = "ARM64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "CPU architecture must be either X86_64 or ARM64."
  }
}

variable "create_service" {
  description = "Whether to create an ECS service (for long-running tasks)"
  type        = bool
  default     = true
}

variable "desired_count" {
  description = "Desired number of tasks for the ECS service"
  type        = number
  default     = 1
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP to the task (Fargate only)"
  type        = bool
  default     = false
}

variable "service_discovery_arn" {
  description = "Service discovery registry ARN"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "additional_environment_variables" {
  description = "Additional environment variables for the container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "additional_secrets" {
  description = "Additional secrets for the container"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "health_check_enabled" {
  description = "Enable container health checks"
  type        = bool
  default     = true
}

variable "health_check_command" {
  description = "Health check command"
  type        = list(string)
  default     = ["CMD-SHELL", "curl -f http://localhost:13133/ || exit 1"]
}

variable "health_check_start_period" {
  description = "Health check start period in seconds"
  type        = number
  default     = 30
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
  description = "Health check retries"
  type        = number
  default     = 3
}
