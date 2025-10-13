variable "aws_region" {
  description = "AWS region to deploy to."
  type        = string
  default     = "eu-west-1"
}

variable "otel_config_path" {
  description = "Path to the rendered OpenTelemetry collector configuration file."
  type        = string
}

variable "otel_deb_url" {
  description = "URL of the OpenTelemetry collector .deb package."
  type        = string
  default     = "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.137.0/otelcol-contrib_0.137.0_linux_amd64.deb"
}

variable "instance_type" {
  description = "EC2 instance type to use."
  type        = string
  default     = "t3.small"
}

variable "ssh_key_name" {
  description = "Name of the AWS key pair to create/use."
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key used for the EC2 instance."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key corresponding to ssh_public_key_path. Used for output convenience."
  type        = string
}

variable "ssh_ingress_cidrs" {
  description = "List of CIDR blocks allowed to SSH into the instance."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Additional tags to apply to created resources."
  type        = map(string)
  default     = {}
}
