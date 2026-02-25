# OpenTelemetry Supervised eBPF Profiler (Coralogix Distribution)

This repository contains a containerized eBPF Profiler with OpAMP supervisor.

## Prerequisites

- Docker (version 20.10+)
- Docker Buildx (for multi-architecture builds)
- kubectl (for cluster access)

## Release

The container image is built and pushed to registries via GitHub Actions.
Images are tagged with the supervised eBPF Profiler image version in the following format:

```
coralogix-otel-supervised-ebpf-profiler:v0.1.0
```

### Supported platforms

The container image is built for the following platforms:

- `linux/amd64`
- `linux/arm64`

Windows is not supported at the moment.

## Building

The project uses a Makefile to build container images for the eBPF Profiler
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

> **Note:**
> `make run` starts the container with `--privileged` and `--pid=host`, which are required for eBPF profiling.

### Example configuration files

The `examples` folder contains sample configuration files for
the eBPF profiler and the OpAMP supervisor. These files are only for local
testing and are not part of the released image.

### Configuration variables

| Variable             | Description                            | Default                                   |
|----------------------|----------------------------------------|-------------------------------------------|
| `IMAGE_NAME`         | Container image name                   | `coralogix-otel-supervised-ebpf-profiler` |
| `IMAGE_TAG`          | Container image tag                    | `$(cat CURRENT_IMAGE_VERSION)`            |
| `COLLECTOR_VERSION`  | eBPF Profiler version                  | `$(cat CURRENT_VERSION)`                  |
| `SUPERVISOR_VERSION` | OpAMP Supervisor version               | Same as `COLLECTOR_VERSION`               |
| `PLATFORMS`          | Target platforms for multi-arch builds | `linux/amd64,linux/arm64`                 |

### Available targets

- `build` - Build the supervised eBPF Profiler container image
- `build-multiarch` - Build multi-architecture container image (builds but doesn't export)
- `build-multiarch-push` - Build multi-architecture container image and push to registry
- `help` - Show help message (default)

### Usage examples

#### Basic build

```bash
make build
```

#### Build with a custom eBPF Profiler version

```bash
make build COLLECTOR_VERSION=0.146.0
```

#### Build with custom image tag

```bash
# Build with custom image tag
make build IMAGE_TAG=v0.1.0

# Build with all custom settings
make build IMAGE_TAG=v0.1.0 IMAGE_NAME=coralogix-otel-supervised-ebpf-profiler COLLECTOR_VERSION=0.146.0
```

#### Multi-Architecture Builds

```bash
# Build for multiple architectures (validates build but doesn't export)
make build-multiarch

# Build for custom platforms
make build-multiarch PLATFORMS=linux/amd64,linux/arm64,linux/arm/v7

# Build multi-arch with specific eBPF profiler version and push
make build-multiarch-push COLLECTOR_VERSION=0.146.0
```

> **Note:**
> - `build-multiarch` validates the build across platforms but doesn't export to local Docker (stays in build cache)
> - `build-multiarch-push` builds for all specified platforms and pushes to registry
> - Multi-arch builds require Docker Buildx
> - To use the built image locally, use the single-platform `build` target instead
