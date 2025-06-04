# OpenTelemetry Supervised Collector

This repository contains a containerized OpenTelemetry Collector with OpAMP supervision support.

## Prerequisites

- Docker (version 20.10+)
- Docker Buildx (for multi-architecture builds)

## Building

The project uses a Makefile to build container images for the OpenTelemetry Collector
with the OpAMP supervisor.

### Quick Start

```bash
# Show all available targets and options
make help

# Build with default settings
make build

# Run the container image locally (useful for testing)
make run
```

### Example configuration files

The `examples` folder contain some small examples of configuration files for
the OpenTelemetry Collector and the OpAMP supervisor. These are only used for
testing purposes and are not part of the released image.

### Configuration variables

| Variable            | Description                            | Default                     |
| ------------------- | -------------------------------------- | --------------------------- |
| `IMAGE_NAME`        | Container image name                   | `otel-supervised-collector` |
| `IMAGE_TAG`         | Container image tag                    | `latest`                    |
| `COLLECTOR_VERSION` | OpenTelemetry Collector version        | `0.127.0`                   |
| `REGISTRY`          | Container registry (optional)          | (empty)                     |
| `PLATFORMS`         | Target platforms for multi-arch builds | `linux/amd64,linux/arm64`   |

### Available targets

- `build` - Build the OpenTelemetry supervised collector container image
- `build-multiarch` - Build multi-architecture container image (builds but doesn't export)
- `build-multiarch-push` - Build multi-architecture container image and push to registry
- `push` - Push the container image to registry
- `clean` - Remove local container image
- `help` - Show help message (default)

### Usage examples

#### Basic build
```bash
make build
```

#### Build with a custom OpenTelemetry Collector version
```bash
make build COLLECTOR_VERSION=0.128.0
```

#### Build with custom image tag
```bash
# Build with custom image tag
make build IMAGE_TAG=v1.0.0

# Build with all custom settings
make build IMAGE_TAG=v1.0.0 IMAGE_NAME=supervised-collector COLLECTOR_VERSION=0.129.0
```

#### Multi-Architecture Builds
```bash
# Build for multiple architectures (validates build but doesn't export)
make build-multiarch

# Build for custom platforms
make build-multiarch PLATFORMS=linux/amd64,linux/arm64,linux/arm/v7

# Build multi-arch with specific OTEL version and push
make build-multiarch-push COLLECTOR_VERSION=0.128.0
```

> **Note:**
> - `build-multiarch` validates the build across platforms but doesn't export to local Docker (stays in build cache)
> - `build-multiarch-push` builds for all specified platforms and pushes to registry
> - Multi-arch builds require Docker Buildx
> - To use the built image locally, use the single-platform `build` target instead