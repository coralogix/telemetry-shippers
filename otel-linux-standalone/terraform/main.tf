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
  region = var.aws_region
}

locals {
  name_prefix     = "eco-system-linux-collector"
  otel_config     = trimspace(file(var.otel_config_path))
  otel_config_b64 = base64gzip(local.otel_config)
  common_tags = merge({
    Project   = "eco-system-linux-standalone"
    ManagedBy = "terraform"
    Owner     = "eco-system"
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

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "otel" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for eco-system standalone OpenTelemetry collector"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_ingress_cidrs
  }

  ingress {
    description = "OTLP gRPC"
    from_port   = 4317
    to_port     = 4317
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "OTLP HTTP"
    from_port   = 4318
    to_port     = 4318
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
  key_name   = var.ssh_key_name
  public_key = file(var.ssh_public_key_path)

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-key"
  })
}

resource "aws_instance" "otel" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = element(data.aws_subnets.default.ids, 0)
  vpc_security_group_ids      = [aws_security_group.otel.id]
  key_name                    = aws_key_pair.otel.key_name
  associate_public_ip_address = true
  user_data                   = local.user_data
  user_data_replace_on_change = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ec2"
  })
}
