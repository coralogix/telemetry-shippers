terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.24.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null
}

locals {
  name_prefix     = "otel-govcloud-collector"
  otel_config     = trimspace(file(var.otel_config_path))
  otel_config_b64 = base64gzip(local.otel_config)
  common_tags = merge({
    Project   = "otel-linux-standalone-govcloud"
    ManagedBy = "terraform"
  }, var.tags)
  user_data = templatefile("${path.module}/templates/user_data.sh.tmpl", {
    otel_config_b64           = local.otel_config_b64
    otel_deb_url              = var.otel_deb_url
    enable_demo_workloads     = var.enable_demo_workloads
    enable_telemetrygen       = var.enable_telemetrygen
    telemetrygen_version      = var.telemetrygen_version
    telemetrygen_go_version   = var.telemetrygen_go_version
    telemetrygen_endpoint     = var.telemetrygen_otlp_endpoint
    telemetrygen_insecure     = var.telemetrygen_insecure
    telemetrygen_rate         = tostring(var.telemetrygen_rate_per_second)
    telemetrygen_service_name = var.telemetrygen_service_name
    telemetrygen_duration     = var.telemetrygen_duration
    coralogix_api_key         = var.coralogix_api_key
  })

  create_key_pair = var.ssh_key_name != "" && var.ssh_public_key_path != ""
}

# Ubuntu 22.04 LTS — GovCloud Canonical account: 513442679011
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["513442679011"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# IAM — instance role scoped to EC2 resource detection and SSM access
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "otel" {
  name               = "${local.name_prefix}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "otel_ec2_detection" {
  statement {
    sid    = "EC2ResourceDetection"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ec2:DescribeRegions",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "otel_ec2_detection" {
  name   = "${local.name_prefix}-ec2-detection"
  role   = aws_iam_role.otel.id
  policy = data.aws_iam_policy_document.otel_ec2_detection.json
}

# SSM managed instance core — enables Session Manager as an SSH alternative
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.otel.name
  policy_arn = "arn:aws-us-gov:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "otel" {
  name = "${local.name_prefix}-profile"
  role = aws_iam_role.otel.name
  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

resource "aws_security_group" "otel" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for GovCloud standalone OpenTelemetry collector"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = length(var.ssh_ingress_cidrs) > 0 ? [1] : []
    content {
      description = "SSH access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_ingress_cidrs
    }
  }

  dynamic "ingress" {
    for_each = length(var.otlp_ingress_cidrs) > 0 ? [1] : []
    content {
      description = "OTLP gRPC"
      from_port   = 4317
      to_port     = 4317
      protocol    = "tcp"
      cidr_blocks = var.otlp_ingress_cidrs
    }
  }

  dynamic "ingress" {
    for_each = length(var.otlp_ingress_cidrs) > 0 ? [1] : []
    content {
      description = "OTLP HTTP"
      from_port   = 4318
      to_port     = 4318
      protocol    = "tcp"
      cidr_blocks = var.otlp_ingress_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sg"
  })
}

resource "aws_key_pair" "otel" {
  count      = local.create_key_pair ? 1 : 0
  key_name   = var.ssh_key_name
  public_key = file(var.ssh_public_key_path)

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-key"
  })
}

# ---------------------------------------------------------------------------
# EC2 instance
# ---------------------------------------------------------------------------

resource "aws_instance" "otel" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.otel.id]
  key_name                    = local.create_key_pair ? aws_key_pair.otel[0].key_name : null
  iam_instance_profile        = aws_iam_instance_profile.otel.name
  associate_public_ip_address = var.associate_public_ip_address
  user_data                   = local.user_data
  user_data_replace_on_change = true

  # IMDSv2 required — enforces token-based metadata access
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ec2"
  })
}
