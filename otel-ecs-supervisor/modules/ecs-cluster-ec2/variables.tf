variable "name_prefix" {
  description = "Prefix for resource names created by the ECS cluster module"
  type        = string
}

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "enable_capacity" {
  description = "Whether to create EC2 capacity provider resources"
  type        = bool
  default     = false
}

variable "ecs_capacity_count" {
  description = "Desired, min, and max size for the Auto Scaling Group backing the capacity provider"
  type        = number
  default     = 0
}

variable "vpc_id" {
  description = "VPC ID for the EC2 container instances security group"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs for the Auto Scaling Group"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed inbound access to the EC2 instances"
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

variable "tags" {
  description = "Tags to apply to created resources"
  type        = map(string)
  default     = {}
}

variable "instance_type" {
  description = "Instance type for the Auto Scaling Group"
  type        = string
  default     = "t3.micro"
}

variable "ecs_ami_ssm_parameter" {
  description = "SSM Parameter path to lookup the ECS-optimized AMI"
  type        = string
  default     = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}

variable "managed_scaling_target_capacity" {
  description = "Target capacity percentage for managed scaling"
  type        = number
  default     = 100
}

variable "managed_scaling_min_step" {
  description = "Minimum number of instances added in a scaling event"
  type        = number
  default     = 1
}

variable "managed_scaling_max_step" {
  description = "Maximum number of instances added in a scaling event"
  type        = number
  default     = 1
}
