# Coralogix ECS Collector Example

This Terraform configuration provisions a complete EC2-backed Amazon ECS environment for exercising the Coralogix OpenTelemetry Collector. Running a single apply creates everything needed to ingest sample traces into Coralogix:

- An ECS cluster with Auto Scaling Group capacity that relies on the default VPC subnets.
- A daemon-style OpenTelemetry Collector task (`coralogix-otel-agent`) that runs on every ECS host and ships data using the configuration in `../examples/otel-config.yaml`.
- A `telemetrygen` task definition and service that continually produces OpenTelemetry traces against your chosen OTLP endpoint.

Random suffixes are attached to task definitions and services to avoid name collisions across multiple applies.

## Prerequisites

- Terraform 1.5.7 or newer.
- An AWS account with credentials that can read the default VPC, manage ECS, Auto Scaling, IAM, and CloudWatch Logs.
- A Coralogix Send-Your-Data API key provided either as plain text (`api_key`) or via Secrets Manager (`api_key_secret_arn`).

## Usage

The provided `Makefile` wraps common workflows. Populate the environment variables it expects (for example, `CLUSTER_NAME`, `AWS_REGION`, `API_KEY`) and then run:

```bash
cd terraform
make plan-example
make apply
```

Targets of note:
- `stop` keeps the cluster running while scaling the telemetry generator service (`desired_count=0`).
- `destroy` removes every resource created by this configuration.
- `redeploy` convenience target that runs `destroy` followed by `apply`.

You can also drive Terraform directly without the `Makefile`:

```bash
cd terraform
terraform init
terraform apply \
  -var="cluster_name=otel-ecs-demo" \
  -var="aws_region=eu-west-1" \
  -var="api_key=xxxxxxx"
```

Review `variables.tf` for additional knobs, including instance sizing (`instance_type`, `min_size`, `max_size`), OTEL agent settings (`memory`, `task_execution_role_arn`, health check toggles), and telemetry generator behavior (`rate_per_second`, `duration`, `otel_endpoint`, `otel_insecure`).

## eBPF Profiler Usage (ECS EC2)

Use the Helm values in `../values.yaml` to enable eBPF profiling and ECS-based `service.name` mapping for profiles.

Example:

```yaml
opentelemetry-agent:
  presets:
    ebpfProfiler:
      enabled: true
      reporterInterval: "30s"
    ecsAttributesContainerLogs:
      enabled: true
      profilesServiceName:
        enabled: true
```

With `profilesServiceName.enabled`, profiles `service.name` is mapped with this fallback order:
- `aws.ecs.task.definition.family`
- `aws.ecs.container.name`

Generate the collector config from the chart values:

```bash
cd ..
make otel-config
```

Deploy with Terraform:

```bash
cd terraform
AWS_PROFILE=research \
AWS_REGION=eu-central-1 \
CLUSTER_NAME=otel-ecs-ec2-profiling \
API_KEY="$API_KEY" \
make apply
```

Verify ECS services are healthy:

```bash
aws ecs describe-services \
  --cluster otel-ecs-ec2-profiling \
  --services coralogix-otel-agent-<suffix> telemetrygen-<suffix>
```

Verify profiler startup from CloudWatch logs:

```bash
aws logs tail /ecs/coralogix-otel-agent-<suffix> --since 15m
```

## Outputs

Applying the module surfaces several useful identifiers:
- `ecs_cluster_arn` – ECS cluster ARN.
- `autoscaling_group_name` – backing Auto Scaling Group for container instances.
- `coralogix_otel_agent_task_definition_arn` / `coralogix_otel_agent_service_id` – identifiers for the collector service.
- `telemetrygen_task_definition_arn` / `telemetrygen_service_id` – identifiers for the telemetry generator service.

## Customization Tips

- Adjust the collector configuration by editing `../examples/otel-config.yaml` before applying; it is injected via the `OTEL_CONFIG` environment variable.
- Set `use_api_key_secret=true` and provide `api_key_secret_arn` to avoid committing credentials.
- Apply `tags` to add consistent metadata across supported AWS resources.
