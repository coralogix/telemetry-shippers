variable "aws_region" {
  description = "AWS GovCloud region to deploy into (us-gov-west-1 or us-gov-east-1)."
  type        = string
  default     = "us-gov-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use for authentication."
  type        = string
  default     = ""
}

variable "name_prefix" {
  description = "Prefix applied to all resource names."
  type        = string
  default     = "otel-govcloud"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets (one per AZ). The OTEL collector instance is placed in the first private subnet."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets. Required when enable_nat_gateway is true."
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones to spread subnets across. Must match the length of private_subnet_cidrs and public_subnet_cidrs."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Deploy a NAT gateway so the collector instance can reach coralogixgov.com from a private subnet. Requires public subnets."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs to CloudWatch Logs. Recommended for FedRAMP AU-2/AU-12 compliance."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Retention period in days for VPC Flow Log CloudWatch log group."
  type        = number
  default     = 90
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
