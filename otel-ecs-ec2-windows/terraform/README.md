# Coralogix ECS Collector (Windows)

This Terraform configuration provisions a **Windows-only** EC2-backed Amazon ECS environment for the Coralogix OpenTelemetry Collector:

- An ECS cluster with Auto Scaling Group capacity (Windows Server 2022 Core ECS-optimized AMI).
- A daemon-style OpenTelemetry Collector task (`coralogix-otel-agent`) that runs on every ECS host and ships data using `../examples/otel-config.yaml`.
- A **telemetrygen-windows** ECS service (separate from the agent), sending logs and traces to the OTEL agent via AWS Cloud Map discovery (`agent.otel.local:4317`). Image is pulled from JFrog (`cgx.jfrog.io/coralogix-docker-images/telemetrygen-windows`).
- **Service discovery**: agent tasks register in a private DNS namespace (`otel.local`) so telemetrygen can resolve and connect to an agent instance.
- NAT Gateway and a private subnet so both the instance and task ENIs can reach Coralogix (and Session Manager works via outbound SSM).

Random suffixes are attached to task definitions and services to avoid name collisions across multiple applies.

## Comparison: otel-ecs-ec2-windows vs otel-ecs-ec2 (Linux)

### Terraform / infrastructure

| Aspect                        | otel-ecs-ec2 (Linux)                                                                                                   | otel-ecs-ec2-windows                                                                                                                                                    |
|-------------------------------|------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **OS / AMI**                  | Amazon Linux 2 (SSM: ECS-optimized AL2)                                                                                | Windows Server 2022 Core (SSM: ECS-optimized Windows 2022)                                                                                                              |
| **Networking**                | Default VPC subnets; no NAT Gateway                                                                                    | Private subnet + NAT Gateway (outbound via NAT, Session Manager)                                                                                                        |
| **Agent network mode**        | `host` (shared with instance)                                                                                          | `awsvpc` (task gets its own ENI)                                                                                                                                        |
| **Agent task**                | `pid_mode = host`, privileged, host mounts (`/var/lib/docker`, `/proc`, `/sys/fs/bpf`, etc.)                           | No pid_mode, not privileged; mounts `C:\`, `C:\ProgramData\Amazon\ECS`                                                                                                  |
| **Agent image**               | Configurable (`image` / `image_version`), default Coralogix collector                                                  | `coralogixrepo/coralogix-otel-collector:0.0.0-win-2022-windowsserver-2022`                                                                                              |
| **Telemetrygen**              | Same task network as host → `localhost:4317`; **traces only**; image from Docker Hub (e.g. `ghcr.io/.../telemetrygen`) | Separate ECS service → `agent.otel.local:4317` via **Cloud Map**; **logs + traces**; image from **JFrog** (`cgx.jfrog.io/coralogix-docker-images/telemetrygen-windows`) |
| **Telemetrygen connectivity** | Host network → OTLP endpoint variable (default `localhost:4317`)                                                       | AWS Cloud Map (private DNS `otel.local`, service `agent`); SG rule TCP 4317 from self                                                                                   |
| **Extra resources**           | —                                                                                                                      | Service Discovery namespace + service, `imagePullPolicy: ALWAYS` for telemetrygen                                                                                       |
| **Default instance type**     | `t3.micro`                                                                                                             | `t3.xlarge` (needs 4+ ENIs for agent + telemetrygen tasks)                                                                                                              |

### OTEL config (examples/otel-config.yaml)

| Aspect                    | otel-ecs-ec2 (Linux)                                                                  | otel-ecs-ec2-windows                                                                                                                                                                                                        |
|---------------------------|---------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Logs receivers**        | `filelog` (Docker container logs under `/hostfs/var/lib/docker/containers/`) + `otlp` | `otlp` only (no filelog; Windows containers don’t expose logs as host files like Linux Docker)                                                                                                                              |
| **Logs pipeline**         | `filelog` + `otlp` → processors include `ecsattributes/container-logs`                | `otlp` only (no filelog). **ecsattributes/container-logs** is disabled on Windows (no Docker daemon). Re-enable once the collector supports ECS Task Metadata fallback.                                                     |
| **ECS container metrics** | `awsecscontainermetricsd` (daemon mode: Docker API + ECS metadata)                    | `awsecscontainermetricsd` with **`sidecar: true`** (ECS Task Metadata only; no Docker daemon on Windows)                                                                                                                    |
| **hostmetrics**           | `root_path: /` (Linux paths)                                                          | No `root_path`; Windows-specific filesystem exclusions                                                                                                                                                                      |
| **resourcedetection/env** | `system` + `env` (host.id from OS)                                                    | `env` only (system detector fails in Windows container: "file specified" / host ID). `host.id` / `host.name` still come from the ec2 detector in resourcedetection/region and resourcedetection/entity (instance metadata). |
| **opamp**                 | Enabled (Fleet Management)                                                            | Disabled (extension fails getting host info on Windows container)                                                                                                                                                           |
| **Agent feature gate**    | Not set                                                                               | `--feature-gates=service.profilesSupport`                                                                                                                                                                                   |

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
- `telemetrygen_service_id` / `telemetrygen_task_definition_arn` – telemetrygen ECS service and task definition.

## Customization

- Edit `../examples/otel-config.yaml` before applying; it is injected via the `OTEL_CONFIG` environment variable.
- Set `use_api_key_secret=true` and `api_key_secret_arn` to use Secrets Manager for the API key.
- Use `tags` to add metadata across resources.
