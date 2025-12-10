# OpenTelemetry Collector Installation Scripts

This directory contains installation scripts for deploying the OpenTelemetry Collector with Coralogix integration.

## Installation Options

| Method | Platforms | Use Case |
|--------|-----------|----------|
| [Standalone](./standalone/) | Linux, macOS | Install directly on host as a service |
| [Docker](./docker/) | Any (Docker required) | Run as a container |

## Quick Start

### Standalone (Linux/macOS)

```bash
CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/standalone/coralogix-otel-collector.sh)"
```

### Docker

```bash
CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/docker/docker-install.sh)" \
  -- -c /path/to/config.yaml
```

## Supervisor Mode (Fleet Management)

Both installation methods support supervisor mode for remote configuration via Coralogix Fleet Management:

### Standalone (Linux only)

```bash
CORALOGIX_DOMAIN="us1.coralogix.com" CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/standalone/coralogix-otel-collector.sh)" \
  -- -s
```

### Docker

```bash
CORALOGIX_DOMAIN="us1.coralogix.com" CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://raw.githubusercontent.com/coralogix/telemetry-shippers/master/otel-installer/docker/docker-install.sh)" \
  -- -s
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `CORALOGIX_PRIVATE_KEY` | Yes | Coralogix [Send-Your-Data API key](https://coralogix.com/docs/send-your-data-api-key/) |
| `CORALOGIX_DOMAIN` | Supervisor only | Coralogix [domain](https://coralogix.com/docs/coralogix-domain/) (e.g., `us1.coralogix.com`) |

## Documentation

- [Standalone Installation](./standalone/README.md) - Full documentation for Linux/macOS
- [Docker Installation](./docker/README.md) - Full documentation for Docker deployment

## License

Apache 2.0

