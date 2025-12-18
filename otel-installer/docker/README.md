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
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/docker-install.sh)" \
  -- --config /path/to/config.yaml
```

| Variable | Description |
| --- | --- |
| CORALOGIX_PRIVATE_KEY | Your Coralogix [Send-Your-Data API key](https://coralogix.com/docs/send-your-data-api-key/) |

### Supervisor Mode (Fleet Management)

```bash
CORALOGIX_DOMAIN="<your-domain>" CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/docker-install.sh)" \
  -- --supervisor
```

## Environment Variables

### Required Variables

| Variable | Required | Description |
| --- | --- | --- |
| CORALOGIX_PRIVATE_KEY | Yes | Coralogix [Send-Your-Data API key](https://coralogix.com/docs/send-your-data-api-key/) |
| CORALOGIX_DOMAIN | Supervisor only | Coralogix [domain](https://coralogix.com/docs/coralogix-domain/) |

### Optional Variables

| Variable | Default | Description |
| --- | --- | --- |
| OTLP_GRPC_PORT | 4317 | Host port for OTLP gRPC |
| OTLP_HTTP_PORT | 4318 | Host port for OTLP HTTP |
| HEALTH_CHECK_PORT | 13133 | Host port for health check |
| MEMORY_LIMIT_MIB | 512 | Memory limit in MiB for the collector |
| LISTEN_INTERFACE | 127.0.0.1 | Network interface for receivers to bind to |

### Configuration Environment Variables

The collector configuration can reference these environment variables:

- `${env:OTEL_MEMORY_LIMIT_MIB}` - Memory limit for the memory_limiter processor
- `${env:OTEL_LISTEN_INTERFACE}` - Network interface for receiver endpoints

**Example configuration:**

```yaml
processors:
  memory_limiter:
    check_interval: 5s
    limit_mib: ${env:OTEL_MEMORY_LIMIT_MIB:-512}

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: ${env:OTEL_LISTEN_INTERFACE:-127.0.0.1}:4317
      http:
        endpoint: ${env:OTEL_LISTEN_INTERFACE:-127.0.0.1}:4318

extensions:
  health_check:
    endpoint: ${env:OTEL_LISTEN_INTERFACE:-127.0.0.1}:13133
```

**Notes:**
- `MEMORY_LIMIT_MIB` controls the collector's memory usage to prevent OOM kills
- `LISTEN_INTERFACE` determines network binding:
  - `127.0.0.1` (default): Local only, suitable for agent mode
  - `0.0.0.0`: All interfaces, suitable for gateway mode
  - Specific IP: Bind to a particular network interface

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

### Basic Usage

```bash
# With custom config (recommended)
CORALOGIX_PRIVATE_KEY="<your-private-key>" ./docker-install.sh --config /path/to/config.yaml

# Specific version
CORALOGIX_PRIVATE_KEY="<your-private-key>" ./docker-install.sh --config config.yaml --version 0.140.1

# Supervisor mode
CORALOGIX_DOMAIN="eu2.coralogix.com" CORALOGIX_PRIVATE_KEY="<your-private-key>" ./docker-install.sh --supervisor

# Run in foreground
CORALOGIX_PRIVATE_KEY="<your-private-key>" ./docker-install.sh --config config.yaml --foreground
```

### Gateway Mode with Custom Memory

```bash
# Gateway mode with 2GB memory limit and listen on all interfaces
MEMORY_LIMIT_MIB=2048 LISTEN_INTERFACE=0.0.0.0 \
  CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  ./docker-install.sh --config gateway-config.yaml
```

### Custom Ports

```bash
# Use non-default ports to avoid conflicts
OTLP_GRPC_PORT=14317 OTLP_HTTP_PORT=14318 \
  CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  ./docker-install.sh --config config.yaml
```

### Supervisor Mode with Custom Settings

```bash
# Supervisor mode with custom memory limit
MEMORY_LIMIT_MIB=1024 LISTEN_INTERFACE=0.0.0.0 \
  CORALOGIX_DOMAIN="eu2.coralogix.com" \
  CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  ./docker-install.sh --supervisor
```

### Management Commands

```bash
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

# Upgrade and change memory limit
MEMORY_LIMIT_MIB=2048 CORALOGIX_PRIVATE_KEY="<your-private-key>" \
  ./docker-install.sh --config config.yaml
```

**Note:** You can change environment variables (like `MEMORY_LIMIT_MIB` or `LISTEN_INTERFACE`) during an upgrade by setting them when running the script again.

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
- **Supervisor mode**: Config is managed remotely via Coralogix Fleet Management. The `--config` flag is ignored in supervisor mode with a warning
- **Port conflicts**: Script checks for port availability before starting and provides clear error messages
- **Environment variables**: Configuration files should use environment variable substitution (e.g., `${env:OTEL_MEMORY_LIMIT_MIB}`) to leverage the script's environment variable support
- **Memory management**: The `MEMORY_LIMIT_MIB` environment variable helps prevent OOM kills by configuring the memory_limiter processor
- **Network binding**: Use `LISTEN_INTERFACE=0.0.0.0` for gateway mode (accepts external connections) or `127.0.0.1` for agent mode (local only)
- Container name: `coralogix-otel-collector`
- Container restarts automatically unless stopped (`--restart unless-stopped`)

