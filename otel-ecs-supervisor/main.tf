terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

data "aws_vpc" "default" {
  count   = var.vpc_id == "" ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = var.vpc_id == "" && length(var.subnet_ids) == 0 ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Local values for common configurations
locals {
  name_prefix = var.name_prefix

  # Validation: ensure at least one private key method is provided
  private_key_methods_count = length([
    for method in [var.coralogix_private_key, var.coralogix_private_key_ssm_parameter, var.coralogix_private_key_secret_arn] :
    method if method != ""
  ])

  # Determine the private key source ARN
  private_key_arn = (
    var.coralogix_private_key_secret_arn != "" ? var.coralogix_private_key_secret_arn :
    var.coralogix_private_key_ssm_parameter != "" ? "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.coralogix_private_key_ssm_parameter}" :
    var.coralogix_private_key != "" ? aws_ssm_parameter.coralogix_private_key[0].arn :
    null
  )

  # Default supervisor configuration
  supervisor_config = templatefile("${path.module}/templates/supervisor.yaml", {
    coralogix_domain      = var.coralogix_domain
    coralogix_private_key = "$${PRIVATE_KEY}"
    application_name      = var.application_name
    subsystem_name        = var.subsystem_name
  })

  # Default collector configuration
  collector_config = templatefile("${path.module}/templates/collector.yaml", {
    coralogix_domain = var.coralogix_domain
    application_name = var.application_name
    subsystem_name   = var.subsystem_name
  })


  # Container command - two approaches based on image capabilities
  container_command = var.use_entrypoint_script ? [
    join("", [
      "mkdir -p /tmp/otel && echo \"$SUPERVISOR_CONFIG_CONTENT\" > /tmp/otel/supervisor.yaml && echo \"$OTEL_CONFIG_CONTENT\" > /tmp/otel/config.yaml && /opampsupervisor --config /tmp/otel/supervisor.yaml"
    ])
    ] : [
    "--config", "env:SUPERVISOR_CONFIG_CONTENT"
  ]

  container_entry_point = var.use_entrypoint_script ? ["/bin/sh", "-c"] : ["/opampsupervisor"]
  ecs_cluster_name      = var.ecs_cluster_name != "" ? var.ecs_cluster_name : local.name_prefix
  default_vpc_id        = try(data.aws_vpc.default[0].id, null)
  default_subnet_ids    = try(data.aws_subnets.default[0].ids, [])
  service_vpc_id        = var.vpc_id != "" ? var.vpc_id : local.default_vpc_id
  service_subnet_ids    = length(var.subnet_ids) > 0 ? var.subnet_ids : local.default_subnet_ids
  ecs_capacity_enabled  = var.create_ecs_cluster && var.launch_type == "EC2" && var.ecs_capacity_count > 0
}

# Validation check
resource "null_resource" "validate_private_key" {
  count = local.private_key_methods_count == 0 ? 1 : 0

  provisioner "local-exec" {
    command = "echo 'ERROR: At least one of coralogix_private_key, coralogix_private_key_ssm_parameter, or coralogix_private_key_secret_arn must be provided.' && exit 1"
  }
}

# Validation check: vpc_id required when subnet_ids are provided
resource "null_resource" "validate_network_inputs" {
  count = 1

  lifecycle {
    precondition {
      condition     = length(var.subnet_ids) == 0 || var.vpc_id != ""
      error_message = "vpc_id must be provided when supplying subnet_ids."
    }
  }
}

# SSM Parameter for Coralogix private key (only if provided via variable)
resource "aws_ssm_parameter" "coralogix_private_key" {
  count       = var.coralogix_private_key != "" ? 1 : 0
  name        = "/${local.name_prefix}/coralogix/private-key"
  description = "Coralogix private key for OpenTelemetry Supervisor"
  type        = "SecureString"
  value       = var.coralogix_private_key

  tags = var.tags
}


# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "supervisor" {
  name              = "${local.name_prefix}/supervisor"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

module "ecs_cluster" {
  count  = var.create_ecs_cluster ? 1 : 0
  source = "./modules/ecs-cluster-ec2"

  name_prefix         = local.name_prefix
  cluster_name        = local.ecs_cluster_name
  enable_capacity     = local.ecs_capacity_enabled
  ecs_capacity_count  = var.ecs_capacity_count
  vpc_id              = local.service_vpc_id
  subnet_ids          = local.service_subnet_ids
  allowed_cidr_blocks = var.allowed_cidr_blocks
  tags                = var.tags
}

# ECS Task Execution Role
resource "aws_iam_role" "execution" {
  name = "${local.name_prefix}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom policy for SSM Parameter Store access (only if SSM-based private key is used)
resource "aws_iam_role_policy" "ssm_access" {
  count = var.coralogix_private_key != "" || var.coralogix_private_key_ssm_parameter != "" ? 1 : 0
  name  = "${local.name_prefix}-ssm-access"
  role  = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Resource = concat(
          var.coralogix_private_key != "" ? [aws_ssm_parameter.coralogix_private_key[0].arn] : [],
          var.coralogix_private_key_ssm_parameter != "" ? ["arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.coralogix_private_key_ssm_parameter}"] : []
        )
      }
    ]
  })
}

# Secrets Manager access policy if using secrets manager
resource "aws_iam_role_policy" "secrets_access" {
  count = var.coralogix_private_key_secret_arn != "" ? 1 : 0
  name  = "${local.name_prefix}-secrets-access"
  role  = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.coralogix_private_key_secret_arn
        ]
      }
    ]
  })
}

# ECS Task Role (for the running task)
resource "aws_iam_role" "task" {
  name = "${local.name_prefix}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Task role permissions (minimal for now, can be extended)
resource "aws_iam_role_policy" "task_permissions" {
  name = "${local.name_prefix}-task-permissions"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.supervisor.arn}:*"
      }
    ]
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "supervisor" {
  family                   = "${local.name_prefix}-supervisor"
  requires_compatibilities = var.launch_type == "FARGATE" ? ["FARGATE"] : ["EC2"]
  network_mode             = var.launch_type == "FARGATE" ? "awsvpc" : var.network_mode
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name       = "supervisor"
      image      = var.container_image
      cpu        = 0
      entryPoint = var.use_entrypoint_script ? local.container_entry_point : null
      command    = local.container_command
      environment = concat([
        {
          name  = "OTEL_CONFIG_CONTENT"
          value = var.collector_config != "" ? var.collector_config : local.collector_config
        },
        {
          name  = "SUPERVISOR_CONFIG_CONTENT"
          value = var.supervisor_config != "" ? var.supervisor_config : local.supervisor_config
        }
      ], var.additional_environment_variables)
      essential = true

      secrets = concat([
        {
          name      = "PRIVATE_KEY"
          valueFrom = local.private_key_arn
        }
      ], var.additional_secrets)

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.supervisor.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "supervisor"
        }
      }

      healthCheck = var.health_check_enabled ? {
        command     = var.health_check_command
        startPeriod = var.health_check_start_period
        interval    = var.health_check_interval
        timeout     = var.health_check_timeout
        retries     = var.health_check_retries
      } : null

      mountPoints = []
      portMappings = [
        {
          containerPort = 4317
          protocol      = "tcp"
          name          = "otlp-grpc"
        },
        {
          containerPort = 4318
          protocol      = "tcp"
          name          = "otlp-http"
        },
        {
          containerPort = 13133
          protocol      = "tcp"
          name          = "health-check"
        },
        {
          containerPort = 8888
          protocol      = "tcp"
          name          = "metrics"
        }
      ]
      systemControls = []
      volumesFrom    = []
    }
  ])

  dynamic "runtime_platform" {
    for_each = var.launch_type == "FARGATE" ? [1] : []
    content {
      operating_system_family = "LINUX"
      cpu_architecture        = var.cpu_architecture
    }
  }

  tags = var.tags
}

# Security Group for Fargate
resource "aws_security_group" "supervisor" {
  count       = var.launch_type == "FARGATE" && var.security_group_id == "" ? 1 : 0
  name        = "${local.name_prefix}-supervisor-sg"
  description = "Security group for OpenTelemetry Supervisor"
  vpc_id      = local.service_vpc_id

  # Allow inbound OTLP traffic
  ingress {
    from_port   = 4317
    to_port     = 4317
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    from_port   = 4318
    to_port     = 4318
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-supervisor-sg"
  })
}

# ECS Service (optional)
resource "aws_ecs_service" "supervisor" {
  count           = var.create_service ? 1 : 0
  name            = "${local.name_prefix}-supervisor"
  cluster         = var.create_ecs_cluster ? module.ecs_cluster[0].cluster_id : var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.supervisor.arn
  desired_count   = var.desired_count
  launch_type     = var.launch_type

  dynamic "network_configuration" {
    for_each = var.launch_type == "FARGATE" ? [1] : []
    content {
      subnets          = local.service_subnet_ids
      security_groups  = [var.security_group_id != "" ? var.security_group_id : aws_security_group.supervisor[0].id]
      assign_public_ip = var.assign_public_ip
    }
  }

  dynamic "service_registries" {
    for_each = var.service_discovery_arn != "" ? [1] : []
    content {
      registry_arn = var.service_discovery_arn
    }
  }

  tags = var.tags
}

# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
