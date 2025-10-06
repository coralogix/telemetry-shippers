# Terraform Telemetry Generator Module

## Overview
This module deploys the `telemetrygen` load generator as an ECS service on an existing EC2-backed ECS cluster. It provisions a task definition and service that emit trace traffic to a specified OTLP endpoint, plus the supporting CloudWatch log group.

## Configuration
Adjust the local `Makefile` to tailor the workload before applying. Important settings include:
- `CLUSTER`, `AWS_REGION`, and `AWS_PROFILE` to target the right ECS cluster and AWS account
- `DESIRED`, `RATE`, and `DURATION` to control the number of running tasks and the generated traffic profile
- Endpoint-related variables inherited by Terraform (`otel_endpoint`, insecurity flag) defined in the `TFVARS` block

Run `make plan`, `make apply`, `make stop`, or `make destroy` after updating the Makefile values. The module accepts additional inputs documented in `variables.tf`.
