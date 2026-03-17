# Coralogix ECS Collector (Windows)

This Terraform configuration provisions a **Windows-only** EC2-backed Amazon ECS environment for the Coralogix OpenTelemetry Collector:

- An ECS cluster with Auto Scaling Group capacity (Windows Server 2022 Core ECS-optimized AMI).
- A daemon-style OpenTelemetry Collector task (`coralogix-otel-agent`) that runs on every ECS host and ships data using `../examples/otel-config.yaml`.
- A **telemetrygen-windows** ECS service (separate from the agent), sending logs and traces to the OTEL agent via AWS Cloud Map discovery (`agent.otel.local:4317`).
- A **public ECR** repository for the telemetrygen-windows image (created in us-east-1).
- **Service discovery**: agent tasks register in a private DNS namespace (`otel.local`) so telemetrygen can resolve and connect to an agent instance.
- NAT Gateway and a private subnet so both the instance and task ENIs can reach Coralogix (and Session Manager works via outbound SSM).

Random suffixes are attached to task definitions and services to avoid name collisions across multiple applies.

## Comparison: otel-ecs-ec2-windows vs otel-ecs-ec2 (Linux)

### Terraform / infrastructure

| Aspect | otel-ecs-ec2 (Linux) | otel-ecs-ec2-windows |
|--------|----------------------|------------------------|
| **OS / AMI** | Amazon Linux 2 (SSM: ECS-optimized AL2) | Windows Server 2022 Core (SSM: ECS-optimized Windows 2022) |
| **Networking** | Default VPC subnets; no NAT Gateway | Private subnet + NAT Gateway (outbound via NAT, Session Manager) |
| **Agent network mode** | `host` (shared with instance) | `awsvpc` (task gets its own ENI) |
| **Agent task** | `pid_mode = host`, privileged, host mounts (`/var/lib/docker`, `/proc`, `/sys/fs/bpf`, etc.) | No pid_mode, not privileged; mounts `C:\`, `C:\ProgramData\Amazon\ECS` |
| **Agent image** | Configurable (`image` / `image_version`), default Coralogix collector | Fixed: `opentelemetry-collector-contrib-windows:0.121.0-windows2022` |
| **Telemetrygen** | Same task network as host → `localhost:4317`; **traces only**; image from Docker Hub (e.g. `ghcr.io/.../telemetrygen`) | Separate ECS service → `agent.otel.local:4317` via **Cloud Map**; **logs + traces**; image from **public ECR** (repo created by Terraform) |
| **Telemetrygen connectivity** | Host network → OTLP endpoint variable (default `localhost:4317`) | AWS Cloud Map (private DNS `otel.local`, service `agent`); SG rule TCP 4317 from self |
| **Extra resources** | — | Public ECR repo (us-east-1), Service Discovery namespace + service, `imagePullPolicy: ALWAYS` for telemetrygen |
| **Default instance type** | `t3.micro` | `t3.xlarge` (needs 4+ ENIs for agent + telemetrygen tasks) |

### OTEL config (examples/otel-config.yaml)

| Aspect | otel-ecs-ec2 (Linux) | otel-ecs-ec2-windows |
|--------|----------------------|------------------------|
| **Logs receivers** | `filelog` (Docker container logs under `/hostfs/var/lib/docker/containers/`) + `otlp` | `otlp` only (no filelog; Windows containers don’t expose logs as host files like Linux Docker) |
| **Logs pipeline** | `filelog` + `otlp` → processors include `ecsattributes/container-logs` | `otlp` only; no `ecsattributes/container-logs` |
| **ECS container metrics** | `awsecscontainermetricsd` | `awsecscontainermetrics` (different receiver name for Windows) |
| **Metrics (resource catalog)** | `logs/resource_catalog` uses `hostmetrics` | `logs/resource_catalog` uses `hostmetrics` (same idea) |
| **hostmetrics** | `root_path: /` (Linux paths) | No `root_path`; Windows-specific filesystem exclusions |
| **spanmetrics** | Includes `aggregation_cardinality_limit`, `add_resource_attributes` | Same connectors; Windows config may omit some options (e.g. cardinality limit) depending on collector version |
| **Agent feature gate** | Not set | `--feature-gates=service.profilesSupport` |

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

**Makefile variables:** `CLUSTER_NAME`, `AWS_REGION`, `API_KEY`, `INSTANCE_TYPE` (default `t3.xlarge`), `TASK_CPU` (default 1024), `TASK_MEMORY` (default 2048), `ECS_CONTAINER_START_TIMEOUT` (default 15m).

See `variables.tf` for all options (instance sizing, task CPU/memory, health checks, execution role).

## Outputs

- `ecs_cluster_arn` – ECS cluster ARN.
- `autoscaling_group_name` – Auto Scaling Group for Windows container instances.
- `coralogix_otel_agent_task_definition_arn` / `coralogix_otel_agent_service_id` – collector task and service.
- `ecr_telemetrygen_windows_repository_uri` – public ECR repo URI for telemetrygen-windows.
- `ecr_telemetrygen_windows_registry_id` – registry ID (account ID) for the public ECR repo.
- `telemetrygen_service_id` / `telemetrygen_task_definition_arn` – telemetrygen ECS service and task definition.

## Pushing the telemetrygen-windows image to your public ECR repo

After `terraform apply`, build the Windows image (from the repo root or `telemetrygen-windows-image/`) and push it to the new public ECR repository.

1. **Get the repo URI** (from Terraform output):
   ```bash
   terraform output -raw ecr_telemetrygen_windows_repository_uri
   ```

2. **Log in to Amazon ECR Public** (public ECR is in us-east-1):
   ```bash
   aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws
   ```

3. **Build the image** (from your workstation; requires Docker buildx and a Windows-capable builder):
   ```bash
   cd telemetrygen-windows-image   # from repo root
   make win2022
   ```

4. **Tag and push** (run from repo root; `REPO_URI` is from step 1, e.g. `public.ecr.aws/123456789012/telemetrygen-windows`):
   ```bash
   cd telemetrygen-windows-image
   REPO_URI=$(cd ../otel-ecs-ec2-windows/terraform && terraform output -raw ecr_telemetrygen_windows_repository_uri)
   docker tag telemetrygen-windows:win2022 $REPO_URI:win2022
   docker push $REPO_URI:win2022
   ```

5. **Redeploy the telemetrygen ECS service** so it pulls the new image (optional; only if you already had tasks running before the first push):
   ```bash
   aws ecs update-service --cluster CLUSTER_NAME --service telemetrygen-windows-SUFFIX --force-new-deployment
   ```
   Use the cluster name and service name from your Terraform output `telemetrygen_service_id`.

## Customization

- Edit `../examples/otel-config.yaml` before applying; it is injected via the `OTEL_CONFIG` environment variable.
- Set `use_api_key_secret=true` and `api_key_secret_arn` to use Secrets Manager for the API key.
- Use `tags` to add metadata across resources.
