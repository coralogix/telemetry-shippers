locals {
  cluster_tags = merge({
    Name = var.cluster_name
  }, var.tags)
}

resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = local.cluster_tags
}

data "aws_ssm_parameter" "ecs_ami" {
  count = var.enable_capacity ? 1 : 0
  name  = var.ecs_ami_ssm_parameter
}

resource "aws_security_group" "ecs_instances" {
  count       = var.enable_capacity ? 1 : 0
  name        = "${var.name_prefix}-ecs-instances"
  description = "Security group for ECS container instances"
  vpc_id      = var.vpc_id

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

  ingress {
    from_port   = 13133
    to_port     = 13133
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  ingress {
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name = "${var.name_prefix}-ecs-instances"
  }, var.tags)
}

resource "aws_iam_role" "ecs_instance" {
  count = var.enable_capacity ? 1 : 0
  name  = "${var.name_prefix}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_instance_service" {
  count      = var.enable_capacity ? 1 : 0
  role       = aws_iam_role.ecs_instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs_instance_ssm" {
  count      = var.enable_capacity ? 1 : 0
  role       = aws_iam_role.ecs_instance[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  count = var.enable_capacity ? 1 : 0
  name  = "${var.name_prefix}-ecs-instance-profile"
  role  = aws_iam_role.ecs_instance[0].name
}

resource "aws_launch_template" "ecs" {
  count = var.enable_capacity ? 1 : 0

  name_prefix   = "${var.name_prefix}-lt-"
  image_id      = jsondecode(data.aws_ssm_parameter.ecs_ami[0].value).image_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance[0].name
  }

  vpc_security_group_ids = [aws_security_group.ecs_instances[0].id]

  user_data = base64encode(<<-EOT
    #!/bin/bash
    echo ECS_CLUSTER=${var.cluster_name} >> /etc/ecs/ecs.config
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge({
      Name = "${var.name_prefix}-ecs-instance"
    }, var.tags)
  }
}

resource "aws_autoscaling_group" "ecs" {
  count = var.enable_capacity ? 1 : 0

  name                = "${var.name_prefix}-asg"
  min_size            = var.ecs_capacity_count
  max_size            = var.ecs_capacity_count
  desired_capacity    = var.ecs_capacity_count
  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.ecs[0].id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-ecs-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecs_capacity_provider" "this" {
  count = var.enable_capacity ? 1 : 0
  name  = "${var.name_prefix}-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs[0].arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = var.managed_scaling_target_capacity
      minimum_scaling_step_size = var.managed_scaling_min_step
      maximum_scaling_step_size = var.managed_scaling_max_step
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  count = var.enable_capacity ? 1 : 0

  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = [aws_ecs_capacity_provider.this[0].name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this[0].name
    weight            = 1
    base              = 0
  }
}
