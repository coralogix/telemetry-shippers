# OpenTelemetry Supervised Collector

This repository contains a containerized OpenTelemetry Collector with the [Coralogix OpAMP Supervisor](https://github.com/coralogix/opentelemetry-collector-contrib/tree/main/cmd/opampsupervisor).

## Prerequisites

- Docker (version 20.10+)
- Docker Buildx (for multi-architecture builds)

## Release

The container image is built and pushed to the Coralogix container image repository via GitHub Actions.
Images are available at cgx.jfrog.io/coralogix-docker-images/coralogix-otel-supervised-collector.

### Supported platforms

The container image is built for the following platforms:

- `linux/amd64`
- `linux/arm64`

Windows is not supported at the moment.

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

| Variable             | Description                            | Default                               |
|----------------------|----------------------------------------|---------------------------------------|
| `IMAGE_NAME`         | Container image name                   | `coralogix-otel-supervised-collector` |
| `IMAGE_TAG`          | Container image tag                    | `$(cat CURRENT_IMAGE_VERSION)`        |
| `SUPERVISOR_VERSION` | CX OpAMP Supervisor version            | `$(cat SUPERVISOR_VERSION)`           |
| `COLLECTOR_VERSION`  | OpenTelemetry Collector version        | `$(cat COLLECTOR_VERSION)`            |
| `REGISTRY`           | Container registry (optional)          | (empty)                               |
| `PLATFORMS`          | Target platforms for multi-arch builds | `linux/amd64,linux/arm64`             |

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
make build COLLECTOR_VERSION=$(cat COLLECTOR_VERSION)
```

#### Build with a custom OpAMP Supervisor version

```bash
make build SUPERVISOR_VERSION=$(cat SUPERVISOR_VERSION)
```

#### Build with custom image tag

```bash
# Build with custom image tag
make build IMAGE_TAG=v1.0.0

# Build with all custom settings
make build IMAGE_TAG=v1.0.0 IMAGE_NAME=supervised-collector COLLECTOR_VERSION=$(cat COLLECTOR_VERSION) SUPERVISOR_VERSION=$(cat SUPERVISOR_VERSION)
```

#### Multi-Architecture Builds

```bash
# Build for multiple architectures (validates build but doesn't export)
make build-multiarch

# Build for custom platforms
make build-multiarch PLATFORMS=linux/amd64,linux/arm64,linux/arm/v7

# Build multi-arch with specific OTEL version and push
make build-multiarch-push COLLECTOR_VERSION=$(cat COLLECTOR_VERSION)
```

> **Note:**
> - `build-multiarch` validates the build across platforms but doesn't export to local Docker (stays in build cache)
> - `build-multiarch-push` builds for all specified platforms and pushes to registry
> - Multi-arch builds require Docker Buildx
> - To use the built image locally, use the single-platform `build` target instead
