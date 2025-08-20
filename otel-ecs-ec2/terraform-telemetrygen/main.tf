locals {
  name = "telemetrygen"
  tags = var.tags
}

resource "random_string" "id" {
  length  = 5
  lower   = true
  numeric = true
  upper   = false
  special = false
}

resource "aws_ecs_task_definition" "telemetrygen" {
  family                   = "${local.name}-${random_string.id.result}"
  requires_compatibilities = ["EC2"]
  network_mode             = "host"
  cpu                      = var.task_cpu
  memory                   = var.task_memory

  container_definitions = jsonencode([
    {
      name      = local.name
      image     = var.telemetrygen_image
      essential = true
      command   = concat([
        "traces",
        "--otlp-endpoint", var.otel_endpoint
      ], var.otel_insecure ? ["--otlp-insecure"] : [], [
        "--rate", tostring(var.rate_per_second),
        "--duration", var.duration
      ])
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group" : aws_cloudwatch_log_group.telemetrygen.name,
          "awslogs-region" : coalesce(var.aws_region, "eu-west-1"),
          "awslogs-stream-prefix" : "ecs"
        }
      }
    }
  ])

  tags = merge({
    Name = "${local.name}-${random_string.id.result}"
  }, var.tags)
}

resource "aws_cloudwatch_log_group" "telemetrygen" {
  name              = "/ecs/telemetrygen"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_ecs_service" "telemetrygen" {
  name                               = "${local.name}-${random_string.id.result}"
  cluster                            = var.ecs_cluster_name
  launch_type                        = "EC2"
  task_definition                    = aws_ecs_task_definition.telemetrygen.arn
  desired_count                      = var.desired_count
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0
  enable_ecs_managed_tags            = true

  deployment_controller { type = "ECS" }

  tags = merge({
    Name = "${local.name}-${random_string.id.result}"
  }, var.tags)
}


