variable "region" {
  description = "AWS region to deploy resources into"
  type        = string
}

variable "cluster_name" {
  description = "Logical name for the ECS cluster and related resources"
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
