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
  name_prefix = "povilas-linux-collector"
  otel_config = trimspace(file(var.otel_config_path))
  common_tags = merge({
    Project   = "povilas-linux-standalone"
    ManagedBy = "terraform"
    Owner     = "povilas"
  }, var.tags)
  user_data = templatefile("${path.module}/templates/user_data.sh.tmpl", {
    otel_config  = local.otel_config
    otel_deb_url = var.otel_deb_url
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
  description = "Security group for povilas standalone OpenTelemetry collector"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_ingress_cidrs
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
