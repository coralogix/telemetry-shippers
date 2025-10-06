locals {
  name = "coralogix-otel-agent"
  tags = merge(
    {
      "ecs:taskDefinition:createdFrom" = "terraform"
    },
    var.tags
  )
  otel_config = file("${path.module}/../examples/otel-config.yaml")
}

resource "random_string" "id" {
  length  = 7
  lower   = true
  numeric = true
  upper   = false
  special = false
}

resource "aws_cloudwatch_log_group" "otel_agent" {
  name              = "/ecs/coralogix-otel-agent-${random_string.id.result}"
  retention_in_days = 7
  tags              = local.tags
}

// Using an existing ECS cluster provided via var.ecs_cluster_name

resource "aws_ecs_task_definition" "coralogix_otel_agent" {
  family                   = "${local.name}-${random_string.id.result}"
  cpu                      = max(var.memory, 256)
  memory                   = var.memory
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.task_execution_role_arn
  volume {
    name      = "hostfs"
    host_path = "/var/lib/docker/"
  }
  volume {
    name      = "docker-socket"
    host_path = "/var/run/docker.sock"
  }
  tags = merge(
    {
      Name = "${local.name}-${random_string.id.result}"
    },
    var.tags
  )
  container_definitions = jsonencode([{
    name : local.name
    networkMode : "host"
    image : "${var.image}:${var.image_version}"
    essential : true
    portMappings : [
      {
        containerPort : 4317
        hostPort : 4317
        appProtocol : "grpc"
      },
      {
        containerPort : 4318
        hostPort : 4318
      },
      {
        containerPort : 8888
        hostPort : 8888
      },
      {
        containerPort : 13133
        hostPort : 13133
      },
      {
        containerPort : 14250
        hostPort : 14250
      },
      {
        containerPort : 14268
        hostPort : 14268
      },
      {
        containerPort : 6831
        hostPort : 6831
        protocol : "udp"
      },
      {
        containerPort : 6832
        hostPort : 6832
        protocol : "udp"
      },
      {
        containerPort : 8125
        hostPort : 8125
        protocol : "udp"
      },
      {
        containerPort : 9411
        hostPort : 9411
      }
    ],
    privileged : true,
    mountPoints : [
      {
        sourceVolume : "hostfs"
        containerPath : "/hostfs/var/lib/docker/"
        readOnly : true
      },
      {
        sourceVolume : "docker-socket"
        containerPath : "/var/run/docker.sock"
      }
    ],
    environment : concat([
      {
        name : "MY_POD_IP"
        value : "0.0.0.0"
      }
      ],
      [{
        name : "OTEL_CONFIG"
        value : local.otel_config
      }],
      var.use_api_key_secret != true ? [{
        name : "CORALOGIX_PRIVATE_KEY"
        value : var.api_key
      }] : []),
    secrets : concat(
      var.use_api_key_secret == true ? [{
        name : "CORALOGIX_PRIVATE_KEY"
        valueFrom : var.api_key_secret_arn
      }] : []
    ),
    command : ["--config", "env:OTEL_CONFIG"],
    healthCheck : var.health_check_enabled ? {
      command : ["/healthcheck"]
      startPeriod : var.health_check_start_period
      interval : var.health_check_interval
      timeout : var.health_check_timeout
      retries : var.health_check_retries
    } : null,
    logConfiguration : {
      logDriver : "awslogs",
      options : {
        "awslogs-group" : aws_cloudwatch_log_group.otel_agent.name,
        "awslogs-region" : coalesce(var.aws_region, "eu-west-1"),
        "awslogs-stream-prefix" : "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "coralogix_otel_agent" {
  name                               = "${local.name}-${random_string.id.result}"
  cluster                            = var.ecs_cluster_name
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
  tags = merge(
    {
      Name = "${local.name}-${random_string.id.result}"
    },
    var.tags
  )
}
