# OpenTelemetry Collector Installation Scripts

Deploy the OpenTelemetry Collector with Coralogix integration.

## Installation Methods

| Method         | Platform     | Documentation                                  |
|----------------|--------------|------------------------------------------------|
| **Standalone** | Linux, macOS | [standalone/README.md](./standalone/README.md) |
| **Docker**     | Any          | [docker/README.md](./docker/README.md)         |

## Quick Start

### Linux / macOS

```bash
CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)"
```

**Note:** For specific versions, see [releases](https://github.com/coralogix/telemetry-shippers/releases) (look for `standalone-installer-v*` tags).

**Enable process metrics (Linux only):**

```bash
CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" \
  -- --enable-process-metrics
```

### Docker

```bash
CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/docker-install.sh)" \
  -- -c /path/to/config.yaml
```

**Note:** For specific versions, see [releases](https://github.com/coralogix/telemetry-shippers/releases) (look for `docker-installer-v*` tags).

### Supervisor Mode (Fleet Management)

Enable remote configuration via Coralogix:

```bash
# Linux (standalone)
CORALOGIX_DOMAIN="us1.coralogix.com" CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/coralogix-otel-collector.sh)" \
  -- -s

# Docker
CORALOGIX_DOMAIN="us1.coralogix.com" CORALOGIX_PRIVATE_KEY="your-key" \
  bash -c "$(curl -sSL https://github.com/coralogix/telemetry-shippers/releases/latest/download/docker-install.sh)" \
  -- -s
```

## Environment Variables

| Variable                | Required        | Description                                                                                  |
|-------------------------|-----------------|----------------------------------------------------------------------------------------------|
| `CORALOGIX_PRIVATE_KEY` | Yes             | Coralogix [Send-Your-Data API key](https://coralogix.com/docs/send-your-data-api-key/)       |
| `CORALOGIX_DOMAIN`      | Supervisor only | Coralogix [domain](https://coralogix.com/docs/coralogix-domain/) (e.g., `us1.coralogix.com`) |

## Documentation

- [Standalone Installation (Linux/macOS)](./standalone/README.md) - Full installation guide
- [Docker Installation](./docker/README.md) - Container deployment guide

## License

Apache 2.0
