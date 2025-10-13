# otel-linux-standalone

Standalone Linux configuration generator and deployment workflow for the Coralogix OpenTelemetry collector. The setup mirrors the `otel-ecs-ec2` pattern to render a collector configuration via Helm and then provision an Ubuntu EC2 instance that runs the collector as a systemd service.

## Prerequisites
- `helm` v3 and `yq`
- `terraform` >= 1.5.7
- AWS credentials with access to `eu-west-1` exposed via the `research` profile (default; override with `AWS_PROFILE`)
- An SSH keypair on your workstation (defaults to `~/.ssh/id_rsa[.pub]`)

## Usage

```bash
cd otel-linux-standalone

# Render the collector config and deploy everything (Helm + Terraform)
make deploy

# Show Terraform outputs once the instance is up
make terraform-output

# Tear everything down
make destroy
```

### Customisation

Most settings can be overridden via environment variables when invoking `make`:

```bash
make deploy SSH_PUBLIC_KEY_PATH=~/.ssh/another-key.pub SSH_PRIVATE_KEY_PATH=~/.ssh/another-key INSTANCE_TYPE=t3.medium
```

## Generated configuration
- `make otel-config` writes `build/otel-config.yaml`.
- The config enables:
  - journald log ingestion
  - EC2 resource detection (`resourcedetection/ec2`)
  - host metrics preset with process-level scrapers

## Deployment details
- Ubuntu Jammy (22.04) EC2 instance in `eu-west-1`
- Collector installed from the `.deb` package: `v0.137.0`
- Service managed by systemd (`otelcol-contrib.service`)
- Bootstrap script refuses to finish unless `systemctl is-active` reports success
- All AWS resource names include the `eco-system` prefix for traceability
