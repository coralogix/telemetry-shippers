# Coralogix ECS Collector (Windows)

This Terraform configuration provisions a **Windows-only** EC2-backed Amazon ECS environment for the Coralogix OpenTelemetry Collector:

- An ECS cluster with Auto Scaling Group capacity (Windows Server 2022 Core ECS-optimized AMI).
- A daemon-style OpenTelemetry Collector task (`coralogix-otel-agent`) that runs on every ECS host and ships data using `../examples/otel-config.yaml`.
- NAT Gateway and a private subnet so both the instance and task ENIs can reach Coralogix (and Session Manager works via outbound SSM).

Random suffixes are attached to task definitions and services to avoid name collisions across multiple applies.

## Prerequisites

- Terraform 1.5.7 or newer.
- An AWS account with credentials that can read the default VPC, manage ECS, Auto Scaling, IAM, CloudWatch Logs, and NAT Gateway.
- Default VPC with at least two subnets (one for NAT, one for ECS).
- A Coralogix Send-Your-Data API key (`api_key`) or Secrets Manager (`api_key_secret_arn`).

## Usage

```bash
cd terraform
make plan-example   # set CLUSTER_NAME, AWS_REGION, API_KEY
make apply
```

Or with Terraform directly:

```bash
terraform init
terraform apply \
  -var="cluster_name=my-windows-cluster" \
  -var="aws_region=eu-north-1" \
  -var="api_key=xxxxxxx"
```

**Makefile variables:** `CLUSTER_NAME`, `AWS_REGION`, `API_KEY`, `INSTANCE_TYPE` (default `t3.large`), `TASK_CPU` (default 1024), `TASK_MEMORY` (default 2048), `ECS_CONTAINER_START_TIMEOUT` (default 15m).

See `variables.tf` for all options (instance sizing, task CPU/memory, health checks, execution role).

## Outputs

- `ecs_cluster_arn` – ECS cluster ARN.
- `autoscaling_group_name` – Auto Scaling Group for Windows container instances.
- `coralogix_otel_agent_task_definition_arn` / `coralogix_otel_agent_service_id` – collector task and service.

## Customization

- Edit `../examples/otel-config.yaml` before applying; it is injected via the `OTEL_CONFIG` environment variable.
- Set `use_api_key_secret=true` and `api_key_secret_arn` to use Secrets Manager for the API key.
- Use `tags` to add metadata across resources.
