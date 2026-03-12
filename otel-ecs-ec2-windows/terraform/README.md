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

**Makefile variables:** `CLUSTER_NAME`, `AWS_REGION`, `API_KEY`, `INSTANCE_TYPE` (default `t3.large`), `TASK_CPU` (default 1024), `TASK_MEMORY` (default 2048), `ECS_CONTAINER_START_TIMEOUT` (default 15m). For trace generation: `ENABLE_TELEMETRYGEN` (default true), `TELEMETRYGEN_IMAGE` (leave empty to use the ECR repo created by Terraform), `TELEMETRYGEN_IMAGE_TAG`, `TELEMETRYGEN_RATE`, `TELEMETRYGEN_SERVICE_NAME`. Targets: `make ecr-login` to log Docker into ECR before pushing the image; `make output` to show outputs.

See `variables.tf` for all options (instance sizing, task CPU/memory, health checks, execution role, telemetrygen).

## Outputs

- `ecs_cluster_arn` – ECS cluster ARN.
- `autoscaling_group_name` – Auto Scaling Group for Windows container instances.
- `coralogix_otel_agent_task_definition_arn` / `coralogix_otel_agent_service_id` – collector task and service.
- `telemetrygen_ecr_repository_url` – ECR repository URL for the Windows telemetrygen image (when `enable_telemetrygen` is true).
- `telemetrygen_ecr_repository_arn` – ARN of that ECR repository.

## Customization

- Edit `../examples/otel-config.yaml` before applying; it is injected via the `OTEL_CONFIG` environment variable.
- Set `use_api_key_secret=true` and `api_key_secret_arn` to use Secrets Manager for the API key.
- Use `tags` to add metadata across resources.

## Traces and logs (telemetrygen)

Metrics come from the host, ECS, and the collector. To get **traces** (and optionally **logs**) into Coralogix, the module can run a Windows **telemetrygen** container in the same task as the collector. It sends traces via OTLP to `localhost:4317`.

Terraform creates an **ECR repository** for the telemetrygen image and a **task execution role** (when you don’t provide one) so ECS can pull from ECR. Use that repo and then build/push the image:

1. **Apply** (with `enable_telemetrygen=true`, default). Do not set `telemetrygen_image` so the task uses the new ECR repo.
   ```bash
   make apply   # or terraform apply with your vars
   ```

2. **Authenticate Docker to ECR** and get the repo URL:
   ```bash
   make ecr-login
   terraform output -raw telemetrygen_ecr_repository_url
   # Example: 123456789012.dkr.ecr.eu-north-1.amazonaws.com/mc-windows-ecs-cluster/telemetrygen-windows
   ```

3. **Build and push** the Windows telemetrygen image from `../telemetrygen-windows-image` to that URL (tag must match `telemetrygen_image_tag`, default `0.121.0-windows2022`):
   ```bash
   cd ../telemetrygen-windows-image
   make build IMAGE_REPOSITORY=<repo_url_from_step_2> IMAGE_TAG=0.121.0-windows2022
   docker push <repo_url_from_step_2>:0.121.0-windows2022
   ```

4. **Force a new deployment** so ECS pulls the new image (e.g. in the ECS console: Update service → Force new deployment), or scale the service and let it roll.

To use a different registry instead of the created ECR repo, set `telemetrygen_image` to the full image URI (e.g. `myregistry.io/telemetrygen-windows:0.121.0-windows2022`) and ensure the task execution role (or your own `task_execution_role_arn`) can pull from it.
