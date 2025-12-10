# OpenTelemetry Collector - Docker Installation

Deploy the OpenTelemetry Collector in Docker with Coralogix integration.

## Quick Start

### Regular Mode

```bash
CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/docker/docker-install.sh)" \
  -- -c /path/to/config.yaml
```

### Supervisor Mode (Fleet Management)

```bash
CORALOGIX_DOMAIN="us1.coralogix.com" CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/docker/docker-install.sh)" \
  -- -s
```

## Options

| Option | Description |
|--------|-------------|
| `-v, --version <version>` | Default version (default: from Helm chart) |
| `--collector-version <ver>` | Collector image version (regular mode) |
| `--supervisor-version <ver>` | Supervisor image version (supervisor mode) |
| `-c, --config <path>` | Path to custom configuration file |
| `-s, --supervisor` | Use supervisor mode (requires CORALOGIX_DOMAIN) |
| `-f, --foreground` | Run in foreground (default: detached) |
| `--uninstall` | Stop and remove the container |
| `-h, --help` | Show help message |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `CORALOGIX_PRIVATE_KEY` | Yes | Coralogix private key |
| `CORALOGIX_DOMAIN` | Supervisor only | Coralogix domain (e.g., `us1.coralogix.com`) |

## Images Used

| Mode | Image |
|------|-------|
| Regular | `otel/opentelemetry-collector-contrib` |
| Supervisor | `coralogixrepo/otel-supervised-collector` |

## Exposed Ports

| Port | Purpose |
|------|---------|
| 4317 | OTLP gRPC receiver |
| 4318 | OTLP HTTP receiver |
| 13133 | Health check endpoint |

## Examples

```bash
# With custom config (recommended)
CORALOGIX_PRIVATE_KEY="your-key" ./docker-install.sh -c /path/to/config.yaml

# Specific version
CORALOGIX_PRIVATE_KEY="your-key" ./docker-install.sh -c config.yaml -v 0.140.1

# Supervisor mode
CORALOGIX_DOMAIN="eu2.coralogix.com" CORALOGIX_PRIVATE_KEY="your-key" ./docker-install.sh -s

# Stop the container
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

## Notes

- **Regular mode**: Requires a config file (`-c`). Without it, uses a placeholder config (nop receivers/exporters).
- **Supervisor mode**: Config is managed remotely via Coralogix Fleet Management.
- Running the script again replaces the existing container (no explicit upgrade needed).

