# Example Terraform variables file
# Copy this file to terraform.tfvars and update with your values

# Required variables
vpc_id         = "vpc-0fbd25059853ca8be"
subnet_ids     = ["subnet-05774ec1f33950bec", "subnet-0731bd9c0fb411fdf", "subnet-007cf13c57ed1d083"]
ecs_cluster_id = "israel-blancas-ecs"

# Coralogix configuration
coralogix_domain                    = "app.staging.coralogix.net"
coralogix_private_key_ssm_parameter = "/coralogix/private-key"
application_name                    = "my-app"
subsystem_name                      = "ecs"

# Optional: Use Secrets Manager instead of SSM
# coralogix_private_key_secret_arn = "arn:aws:secretsmanager:REGION:ACCOUNT:secret:NAME"

# Resource configuration
name_prefix   = "my-app-otel"
launch_type   = "FARGATE"
cpu           = 512
memory        = 1024
desired_count = 1

# Network configuration
allowed_cidr_blocks = ["10.0.0.0/8"]
assign_public_ip    = false

# Optional: Custom container image
# container_image = "coralogixrepo/otel-supervised-collector:v0.5.1"

# Optional: Custom configurations
# supervisor_config = file("./custom-supervisor.yaml")
# collector_config  = file("./custom-collector.yaml")

# Health check configuration
health_check_enabled      = false
health_check_start_period = 30
health_check_interval     = 30
health_check_timeout      = 5
health_check_retries      = 3
# health_check_command    = ["CMD-SHELL", "curl -f http://localhost:13133/ || exit 1"]

# Tags
tags = {
  Environment = "test"
  Team        = "platform"
  Project     = "observability"
}