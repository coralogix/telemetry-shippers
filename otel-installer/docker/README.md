# Docker Installation

Deploy the OpenTelemetry Collector in Docker with Coralogix integration.

## Overview

This script runs the Coralogix OpenTelemetry Collector as a Docker container, supporting:
- **Regular mode**: Local configuration file
- **Supervisor mode**: Remote configuration via Fleet Management

## Prerequisites

- Docker installed and running
- `curl` command
- Coralogix [Send-Your-Data API key](https://coralogix.com/docs/send-your-data-api-key/)
- For Supervisor mode: Coralogix [domain](https://coralogix.com/docs/coralogix-domain/)

## Quick Start

### Regular Mode

```bash
CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/docker/docker-install.sh)" \
  -- --config /path/to/config.yaml
```

| Variable | Description |
| --- | --- |
| CORALOGIX_PRIVATE_KEY | Your Coralogix [Send-Your-Data API key](https://coralogix.com/docs/send-your-data-api-key/) |

### Supervisor Mode (Fleet Management)

```bash
CORALOGIX_DOMAIN="<your-domain>" CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/docker/docker-install.sh)" \
  -- --supervisor
```

## Environment Variables

| Variable | Required | Description |
| --- | --- | --- |
| CORALOGIX_PRIVATE_KEY | Yes | Coralogix [Send-Your-Data API key](https://coralogix.com/docs/send-your-data-api-key/) |
| CORALOGIX_DOMAIN | Supervisor only | Coralogix [domain](https://coralogix.com/docs/coralogix-domain/) |
| OTLP_GRPC_PORT | No | Host port for OTLP gRPC (default: 4317) |
| OTLP_HTTP_PORT | No | Host port for OTLP HTTP (default: 4318) |
| HEALTH_CHECK_PORT | No | Host port for health check (default: 13133) |

## Script Options

| Option | Description |
| --- | --- |
| `-v, --version <version>` | Default version (default: from Helm chart) |
| `--collector-version <version>` | Collector image version |
| `--supervisor-version <version>` | Supervisor image version |
| `-c, --config <path>` | Path to custom configuration file |
| `-s, --supervisor` | Use supervisor mode |
| `-f, --foreground` | Run in foreground (default: detached) |
| `--uninstall` | Stop and remove the container |
| `-h, --help` | Show help message |

## Container Images

| Mode | Image |
| --- | --- |
| Regular | `otel/opentelemetry-collector-contrib` |
| Supervisor | `coralogixrepo/otel-supervised-collector` |

## Exposed Ports

| Port | Purpose | Override |
| --- | --- | --- |
| 4317 | OTLP gRPC receiver | `OTLP_GRPC_PORT` |
| 4318 | OTLP HTTP receiver | `OTLP_HTTP_PORT` |
| 13133 | Health check endpoint | `HEALTH_CHECK_PORT` |

If ports conflict with existing services, override them:

```bash
OTLP_GRPC_PORT=14317 OTLP_HTTP_PORT=14318 CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  ./docker-install.sh --config config.yaml
```

## Examples

```bash
# With custom config (recommended)
CORALOGIX_PRIVATE_KEY="<your-private-key>" ./docker-install.sh --config /path/to/config.yaml

# Specific version
CORALOGIX_PRIVATE_KEY="<your-private-key>" ./docker-install.sh --config config.yaml --version 0.140.1

# Supervisor mode
CORALOGIX_DOMAIN="eu2.coralogix.com" CORALOGIX_PRIVATE_KEY="<your-private-key>" ./docker-install.sh --supervisor

# Run in foreground
CORALOGIX_PRIVATE_KEY="<your-private-key>" ./docker-install.sh --config config.yaml --foreground

# Stop and remove
./docker-install.sh --uninstall
```

## Container Management

```bash
# View logs
docker logs -f coralogix-otel-collector

# Check status
docker ps | grep coralogix-otel-collector

# Health check
curl -s http://localhost:13133/health

# Restart
docker restart coralogix-otel-collector

# Stop and remove
docker stop coralogix-otel-collector && docker rm coralogix-otel-collector
```

## Upgrade

Running the script again automatically replaces the existing container with the new version:

```bash
# Upgrade to latest
CORALOGIX_PRIVATE_KEY="<your-private-key>" ./docker-install.sh --config config.yaml

# Upgrade to specific version
CORALOGIX_PRIVATE_KEY="<your-private-key>" ./docker-install.sh --config config.yaml --version 0.141.0
```

## Uninstall

```bash
./docker-install.sh --uninstall
```

Or manually:

```bash
docker stop coralogix-otel-collector && docker rm coralogix-otel-collector
```

## Notes

- **Config storage**: Config files are stored in `~/.coralogix-otel-collector/` and persist across reboots
- **Regular mode**: Requires a config file (`--config`). Without it, uses a placeholder config with nop receivers/exporters
- **Supervisor mode**: Config is managed remotely via Coralogix Fleet Management
- **Port conflicts**: Script checks for port availability before starting and provides clear error messages
- Container name: `coralogix-otel-collector`
- Container restarts automatically unless stopped (`--restart unless-stopped`)

## License

Apache 2.0
