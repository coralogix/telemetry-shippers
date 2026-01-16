terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.24.0"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_ssm_parameter" "ecs_ami" {
  name = var.ecs_ami_ssm_parameter
}

locals {
  default_tags         = var.tags != null ? var.tags : {}
  ecs_ami              = jsondecode(data.aws_ssm_parameter.ecs_ami.value)
  cluster_subnet_ids   = data.aws_subnets.default.ids
  agent_name           = "coralogix-otel-agent"
  telemetrygen_name    = "telemetrygen"
  otel_config          = file("${path.module}/../examples/otel-config.yaml")
  agent_service_suffix = random_string.agent_suffix.result
  telemetry_suffix     = random_string.telemetrygen_suffix.result
}

resource "aws_security_group" "ecs_instances" {
  name        = "${var.cluster_name}-ecs-instances"
  description = "Allow outbound traffic for ECS instances"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name = "${var.cluster_name}-ecs-sg"
  }, local.default_tags)
}

resource "aws_iam_role" "ecs_instance" {
  name = "${var.cluster_name}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_service" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ssm" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${var.cluster_name}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance.name
}

resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.cluster_name}-lt-"
  image_id      = local.ecs_ami.image_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance.name
  }

  vpc_security_group_ids = [aws_security_group.ecs_instances.id]

  user_data = base64encode(<<-EOT
    #!/bin/bash
    echo ECS_CLUSTER=${var.cluster_name} >> /etc/ecs/ecs.config
    cat >/etc/sysctl.d/99-ebpf.conf <<'SYSCTL'
    kernel.perf_event_paranoid=1
    SYSCTL
    sysctl -p /etc/sysctl.d/99-ebpf.conf
  EOT
  )

  tag_specifications {
    resource_type = "instance"

    tags = merge({
      Name = "${var.cluster_name}-ecs"
    }, local.default_tags)
  }
}

resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = merge({
    Name = var.cluster_name
  }, local.default_tags)
}

resource "aws_autoscaling_group" "ecs" {
  name                = "${var.cluster_name}-asg"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = local.cluster_subnet_ids

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-ecs"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_ecs_cluster.this]
}

resource "random_string" "agent_suffix" {
  length  = 7
  lower   = true
  numeric = true
  upper   = false
  special = false
}

resource "random_string" "telemetrygen_suffix" {
  length  = 5
  lower   = true
  numeric = true
  upper   = false
  special = false
}

resource "aws_cloudwatch_log_group" "otel_agent" {
  name              = "/ecs/${local.agent_name}-${local.agent_service_suffix}"
  retention_in_days = 7
  tags              = local.default_tags
}

resource "aws_ecs_task_definition" "coralogix_otel_agent" {
  family                   = "${local.agent_name}-${local.agent_service_suffix}"
  cpu                      = max(var.memory, 256)
  memory                   = var.memory
  network_mode             = "host"
  pid_mode                 = "host"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.task_execution_role_arn != null ? var.task_execution_role_arn : null

  volume {
    name      = "hostfs"
    host_path = "/var/lib/docker/"
  }

  volume {
    name      = "docker-socket"
    host_path = "/var/run/docker.sock"
  }

  volume {
    name      = "host-proc"
    host_path = "/proc"
  }

  volume {
    name      = "host-dev"
    host_path = "/dev"
  }

  volume {
    name      = "cgroup"
    host_path = "/sys/fs/cgroup"
  }

  volume {
    name      = "debugfs"
    host_path = "/sys/kernel/debug"
  }

  volume {
    name      = "bpf"
    host_path = "/sys/fs/bpf"
  }

  volume {
    name      = "tracefs"
    host_path = "/sys/kernel/tracing"
  }

  container_definitions = jsonencode([
    {
      name       = local.agent_name
      image      = "${var.image}:${var.image_version}"
      essential  = true
      privileged = true
      portMappings = [
        { containerPort = 4317, hostPort = 4317, appProtocol = "grpc" },
        { containerPort = 4318, hostPort = 4318 },
        { containerPort = 8888, hostPort = 8888 },
        { containerPort = 13133, hostPort = 13133 },
        { containerPort = 14250, hostPort = 14250 },
        { containerPort = 14268, hostPort = 14268 },
        { containerPort = 6831, hostPort = 6831, protocol = "udp" },
        { containerPort = 6832, hostPort = 6832, protocol = "udp" },
        { containerPort = 8125, hostPort = 8125, protocol = "udp" },
        { containerPort = 9411, hostPort = 9411 }
      ]
      mountPoints = [
        { sourceVolume = "hostfs", containerPath = "/hostfs/var/lib/docker/", readOnly = true },
        { sourceVolume = "docker-socket", containerPath = "/var/run/docker.sock" },
        { sourceVolume = "host-proc", containerPath = "/proc", readOnly = true },
        { sourceVolume = "host-dev", containerPath = "/dev" },
        { sourceVolume = "cgroup", containerPath = "/sys/fs/cgroup", readOnly = true },
        { sourceVolume = "debugfs", containerPath = "/sys/kernel/debug", readOnly = true },
        { sourceVolume = "bpf", containerPath = "/sys/fs/bpf" },
        { sourceVolume = "tracefs", containerPath = "/sys/kernel/tracing", readOnly = true }
      ]
      environment = concat([
        {
          name  = "MY_POD_IP"
          value = "0.0.0.0"
        },
        {
          name  = "OTEL_CONFIG"
          value = local.otel_config
        }
        ],
        var.use_api_key_secret ? [] : [
          {
            name  = "CORALOGIX_PRIVATE_KEY"
            value = var.api_key
          }
      ])
      secrets = var.use_api_key_secret ? [
        {
          name      = "CORALOGIX_PRIVATE_KEY"
          valueFrom = var.api_key_secret_arn
        }
      ] : []
      command = ["--config", "env:OTEL_CONFIG", "--feature-gates=service.profilesSupport"]
      healthCheck = var.health_check_enabled ? {
        command     = ["/healthcheck"]
        startPeriod = var.health_check_start_period
        interval    = var.health_check_interval
        timeout     = var.health_check_timeout
        retries     = var.health_check_retries
      } : null
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.otel_agent.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = merge({
    Name = "${local.agent_name}-${local.agent_service_suffix}"
  }, local.default_tags)
}

resource "aws_ecs_service" "coralogix_otel_agent" {
  name                               = "${local.agent_name}-${local.agent_service_suffix}"
  cluster                            = aws_ecs_cluster.this.id
  launch_type                        = "EC2"
  task_definition                    = aws_ecs_task_definition.coralogix_otel_agent.arn
  scheduling_strategy                = "DAEMON"
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_controller {
    type = "ECS"
  }

  service_connect_configuration {
    enabled = false
  }

  enable_ecs_managed_tags = true

  tags = merge({
    Name = "${local.agent_name}-${local.agent_service_suffix}"
  }, local.default_tags)
}

resource "aws_cloudwatch_log_group" "telemetrygen" {
  name              = "/ecs/${local.telemetrygen_name}-${local.telemetry_suffix}"
  retention_in_days = 7
  tags              = local.default_tags
}

resource "aws_ecs_task_definition" "telemetrygen" {
  family                   = "${local.telemetrygen_name}-${local.telemetry_suffix}"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = "host"
  requires_compatibilities = ["EC2"]

  container_definitions = jsonencode([
    {
      name      = local.telemetrygen_name
      image     = var.telemetrygen_image
      essential = true
      command = concat([
        "traces",
        "--otlp-endpoint",
        var.otel_endpoint
        ], var.otel_insecure ? ["--otlp-insecure"] : [], [
        "--rate",
        tostring(var.rate_per_second),
        "--duration",
        var.duration
      ])
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.telemetrygen.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = merge({
    Name = "${local.telemetrygen_name}-${local.telemetry_suffix}"
  }, local.default_tags)
}

resource "aws_ecs_service" "telemetrygen" {
  name                               = "${local.telemetrygen_name}-${local.telemetry_suffix}"
  cluster                            = aws_ecs_cluster.this.id
  launch_type                        = "EC2"
  task_definition                    = aws_ecs_task_definition.telemetrygen.arn
  desired_count                      = var.desired_count
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0
  enable_ecs_managed_tags            = true

  deployment_controller {
    type = "ECS"
  }

  tags = merge({
    Name = "${local.telemetrygen_name}-${local.telemetry_suffix}"
  }, local.default_tags)
}