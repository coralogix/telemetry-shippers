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

# Public ECR is only available in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
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

# NAT Gateway: task ENIs use a separate private IP that the IGW does not NAT.
# NAT lives in a public subnet (subnet 0); ECS runs in a private subnet (subnet 1) that routes
# outbound via NAT. Session Manager works via outbound to SSM.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge({ Name = "${var.cluster_name}-nat-eip" }, local.default_tags)
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = local.cluster_subnet_ids[0]
  tags          = merge({ Name = "${var.cluster_name}-nat" }, local.default_tags)
}

resource "aws_route_table" "ecs_nat" {
  vpc_id = data.aws_vpc.default.id
  tags   = merge({ Name = "${var.cluster_name}-ecs-nat-rt" }, local.default_tags)
}

resource "aws_route" "ecs_nat_default" {
  route_table_id         = aws_route_table.ecs_nat.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "ecs_nat" {
  subnet_id      = local.cluster_subnet_ids[1]
  route_table_id = aws_route_table.ecs_nat.id
}

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Core-ECS_Optimized"
}

locals {
  default_tags       = var.tags != null ? var.tags : {}
  ecs_ami            = jsondecode(data.aws_ssm_parameter.ecs_ami.value)
  cluster_subnet_ids = data.aws_subnets.default.ids
  agent_name         = "coralogix-otel-agent"
  otel_config        = file("${path.module}/../examples/otel-config.yaml")
  agent_suffix       = random_string.agent_suffix.result
  agent_image        = "coralogixrepo/coralogix-otel-collector:0.0.0-win-2022-windowsserver-2022"
  # TODO: Remove ECR fallback once telemetrygen-windows-image is published to Docker Hub (coralogixrepo/telemetrygen-windows); then default to that image.
  telemetrygen_image = coalesce(var.telemetrygen_image, "${aws_ecrpublic_repository.telemetrygen_windows.repository_uri}:v0.147.0-win2022")

  agent_volumes = [
    { name = "hostfs", host_path = "C:\\" },
    { name = "programdata", host_path = "C:\\ProgramData\\Amazon\\ECS" }
  ]

  agent_common = {
    name       = local.agent_name
    image      = local.agent_image
    cpu        = var.task_cpu
    memory     = var.task_memory
    essential  = true
    privileged = false
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
    environment = concat([
      { name = "MY_POD_IP", value = "0.0.0.0" },
      { name = "OTEL_CONFIG", value = local.otel_config }
    ], var.use_api_key_secret ? [] : [{ name = "CORALOGIX_PRIVATE_KEY", value = var.api_key }])
    secrets = var.use_api_key_secret ? [{ name = "CORALOGIX_PRIVATE_KEY", valueFrom = var.api_key_secret_arn }] : []
    command = ["--config", "env:OTEL_CONFIG", "--feature-gates=service.profilesSupport"]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.otel_agent.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }

  agent_mounts = [
    { sourceVolume = "hostfs", containerPath = "C:\\hostfs", readOnly = true },
    { sourceVolume = "programdata", containerPath = "C:\\ProgramData\\Amazon\\ECS", readOnly = true }
  ]

  agent_healthcheck = var.health_check_enabled ? {
    command     = ["cmd", "/c", "exit", "0"]
    startPeriod = var.health_check_start_period
    interval    = var.health_check_interval
    timeout     = var.health_check_timeout
    retries     = var.health_check_retries
  } : null

  telemetrygen_name   = "telemetrygen-windows"
  telemetrygen_suffix = random_string.agent_suffix.result
  # Telemetrygen reaches the agent via Cloud Map DNS (resolves to any agent task)
  otel_agent_endpoint = "${aws_service_discovery_service.agent.name}.${aws_service_discovery_private_dns_namespace.otel.name}:4317"
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

# Allow telemetrygen tasks to reach agent tasks on OTLP gRPC port (separate rule to avoid SG replacement)
resource "aws_security_group_rule" "ecs_otlp_from_self" {
  type              = "ingress"
  from_port         = 4317
  to_port           = 4317
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.ecs_instances.id
  description       = "OTLP gRPC from telemetrygen to agent"
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

# Task execution role: used by ECS to pull images (ECR) and write logs. Created only when not provided.
resource "aws_iam_role" "ecs_task_execution" {
  count = var.task_execution_role_arn == null ? 1 : 0

  name = "${var.cluster_name}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  count      = var.task_execution_role_arn == null ? 1 : 0
  role       = aws_iam_role.ecs_task_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.cluster_name}-lt-"
  image_id      = local.ecs_ami.image_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance.name
  }

  network_interfaces {
    subnet_id                   = local.cluster_subnet_ids[1]
    security_groups             = [aws_security_group.ecs_instances.id]
    associate_public_ip_address = false
    device_index                = 0
  }

  user_data = base64encode(<<-EOT
    <powershell>
    [Environment]::SetEnvironmentVariable("ECS_ENABLE_AWSLOGS_EXECUTIONROLE_OVERRIDE", $TRUE, "Machine")
    if ("${var.ecs_container_start_timeout}" -ne "") {
      [Environment]::SetEnvironmentVariable("ECS_CONTAINER_START_TIMEOUT", "${var.ecs_container_start_timeout}", "Machine")
    }
    Initialize-ECSAgent -Cluster ${var.cluster_name} -EnableTaskIAMRole -LoggingDrivers '["json-file","awslogs"]' -EnableTaskENI
    </powershell>
    EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags          = merge({ Name = "${var.cluster_name}-ecs" }, local.default_tags)
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
  vpc_zone_identifier = [local.cluster_subnet_ids[1]]

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

# Public ECR repository for telemetrygen-windows image (us-east-1 only).
# TODO: Remove this resource (and switch telemetrygen_image default to Docker Hub) once telemetrygen-windows-image is published to Docker Hub.
resource "aws_ecrpublic_repository" "telemetrygen_windows" {
  provider = aws.us_east_1

  repository_name = var.telemetrygen_ecr_repository_name

  catalog_data {
    description       = "Telemetrygen Windows image (logs + traces) for OpenTelemetry testing"
    architectures     = ["AMD64"]
    operating_systems = ["WINDOWS"]
  }

  tags = merge({
    Name = var.telemetrygen_ecr_repository_name
  }, local.default_tags)
}

resource "aws_cloudwatch_log_group" "otel_agent" {
  name              = "/ecs/${local.agent_name}-${local.agent_suffix}"
  retention_in_days = 7
  tags              = local.default_tags
}

resource "aws_cloudwatch_log_group" "telemetrygen" {
  name              = "/ecs/telemetrygen-windows-${local.agent_suffix}"
  retention_in_days = 7
  tags              = local.default_tags
}

# Service discovery: agent tasks register so telemetrygen can resolve agent.otel.local:4317
resource "aws_service_discovery_private_dns_namespace" "otel" {
  name        = "otel.local"
  description = "Private DNS namespace for OTEL agent discovery"
  vpc         = data.aws_vpc.default.id
  tags        = merge({ Name = "${var.cluster_name}-otel-discovery" }, local.default_tags)
}

resource "aws_service_discovery_service" "agent" {
  name = "agent"

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.otel.id
    routing_policy = "MULTIVALUE"
    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  tags = merge({ Name = "${var.cluster_name}-agent-discovery" }, local.default_tags)
}

resource "aws_ecs_task_definition" "coralogix_otel_agent" {
  family                   = "${local.agent_name}-${local.agent_suffix}"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.task_execution_role_arn != null ? var.task_execution_role_arn : aws_iam_role.ecs_task_execution[0].arn

  volume {
    name      = "hostfs"
    host_path = "C:\\"
  }

  volume {
    name      = "programdata"
    host_path = "C:\\ProgramData\\Amazon\\ECS"
  }

  runtime_platform {
    operating_system_family = "WINDOWS_SERVER_2022_CORE"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    merge(
      local.agent_common,
      {
        mountPoints = local.agent_mounts
        healthCheck = local.agent_healthcheck
      }
    )
  ])

  tags = merge({
    Name = "${local.agent_name}-${local.agent_suffix}"
  }, local.default_tags)
}

resource "aws_ecs_service" "coralogix_otel_agent" {
  name                               = "${local.agent_name}-${local.agent_suffix}"
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

  network_configuration {
    subnets         = [local.cluster_subnet_ids[1]]
    security_groups = [aws_security_group.ecs_instances.id]
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.agent.arn
    container_name = local.agent_name
  }

  enable_ecs_managed_tags = true

  tags = merge({
    Name = "${local.agent_name}-${local.agent_suffix}"
  }, local.default_tags)
}

# --- Telemetrygen as a separate ECS service ---

resource "aws_ecs_task_definition" "telemetrygen" {
  family                   = "${local.telemetrygen_name}-${local.telemetrygen_suffix}"
  cpu                      = var.telemetrygen_cpu
  memory                   = var.telemetrygen_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.task_execution_role_arn != null ? var.task_execution_role_arn : aws_iam_role.ecs_task_execution[0].arn

  runtime_platform {
    operating_system_family = "WINDOWS_SERVER_2022_CORE"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name            = local.telemetrygen_name
      image           = local.telemetrygen_image
      imagePullPolicy = "ALWAYS"
      cpu             = var.telemetrygen_cpu
      memory          = var.telemetrygen_memory
      essential       = true
      environment = [
        { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = local.otel_agent_endpoint },
        { name = "OTEL_INSECURE", value = "true" },
        { name = "TELEMETRYGEN_RATE", value = tostring(var.telemetrygen_rate) },
        { name = "TELEMETRYGEN_DURATION", value = var.telemetrygen_duration },
        { name = "TELEMETRYGEN_SERVICE", value = var.telemetrygen_service_name }
      ]
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
    Name = "${local.telemetrygen_name}-${local.telemetrygen_suffix}"
  }, local.default_tags)
}

resource "aws_ecs_service" "telemetrygen" {
  name                               = "${local.telemetrygen_name}-${local.telemetrygen_suffix}"
  cluster                            = aws_ecs_cluster.this.id
  launch_type                        = "EC2"
  task_definition                    = aws_ecs_task_definition.telemetrygen.arn
  desired_count                      = var.telemetrygen_desired_count
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    subnets         = [local.cluster_subnet_ids[1]]
    security_groups = [aws_security_group.ecs_instances.id]
  }

  enable_ecs_managed_tags = true

  tags = merge({
    Name = "${local.telemetrygen_name}-${local.telemetrygen_suffix}"
  }, local.default_tags)
}
