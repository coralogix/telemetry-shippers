# OpenTelemetry Supervised Collector (Coralogix Distribution)

This repository contains a containerized Coralogix OpenTelemetry Collector (cdot)
with OpAMP supervisor.

## Prerequisites

- Docker (version 20.10+)
- Docker Buildx (for multi-architecture builds)

## Release

The container image is built and pushed to registries via GitHub Actions.
Images are tagged with the supervised CDOT image version in the following format:

```
coralogix-otel-supervised-cdot:v0.0.1
```

### Supported platforms

The container image is built for the following platforms:

- `linux/amd64`
- `linux/arm64`

Windows is not supported at the moment.

## Building

The project uses a Makefile to build container images for the Coralogix collector
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
the Coralogix OpenTelemetry Collector and the OpAMP supervisor. These are only used for
testing purposes and are not part of the released image.

### Configuration variables

| Variable             | Description                            | Default                             |
|----------------------|----------------------------------------|-------------------------------------|
| `IMAGE_NAME`         | Container image name                   | `coralogix-otel-supervised-cdot`    |
| `IMAGE_TAG`          | Container image tag                    | `$(cat CURRENT_IMAGE_VERSION)`      |
| `COLLECTOR_VERSION`  | Coralogix OTEL Collector version       | `$(cat CURRENT_COLLECTOR_VERSION)`  |
| `SUPERVISOR_VERSION` | OpAMP Supervisor version               | `$(cat CURRENT_SUPERVISOR_VERSION)` |
| `REGISTRY`           | Container registry (optional)          | (empty)                             |
| `PLATFORMS`          | Target platforms for multi-arch builds | `linux/amd64,linux/arm64`           |

### Available targets

- `build` - Build the supervised CDOT container image
- `build-multiarch` - Build multi-architecture container image (builds but doesn't export)
- `build-multiarch-push` - Build multi-architecture container image and push to registry
- `help` - Show help message (default)

### Usage examples

#### Basic build

```bash
make build
```

#### Build with a custom Coralogix collector version

```bash
make build COLLECTOR_VERSION=v0.5.7
```

#### Build with a custom OpAMP Supervisor version

```bash
make build SUPERVISOR_VERSION=0.141.0
```

#### Build with custom image tag

```bash
# Build with custom image tag
make build IMAGE_TAG=v1.0.0

# Build with all custom settings
make build IMAGE_TAG=v1.0.0 IMAGE_NAME=coralogix-otel-supervised-cdot COLLECTOR_VERSION=v0.5.7
```

#### Multi-Architecture Builds

```bash
# Build for multiple architectures (validates build but doesn't export)
make build-multiarch

# Build for custom platforms
make build-multiarch PLATFORMS=linux/amd64,linux/arm64,linux/arm/v7

# Build multi-arch with specific CDOT version and push
make build-multiarch-push COLLECTOR_VERSION=v0.5.7
```

> **Note:**
> - `build-multiarch` validates the build across platforms but doesn't export to local Docker (stays in build cache)
> - `build-multiarch-push` builds for all specified platforms and pushes to registry
> - Multi-arch builds require Docker Buildx
> - To use the built image locally, use the single-platform `build` target instead
