# Windows telemetrygen image

Generates traces (and optionally metrics/logs) via OTLP for testing the Coralogix collector on Windows ECS.

Built from [opentelemetry-collector-contrib](https://github.com/open-telemetry/opentelemetry-collector-contrib) at the same version as the collector (0.121.0). Cross-compiled for Windows from Linux, then run on Windows Server Core 2022.

## Build (on a machine with Docker and Linux builder)

```bash
make build
# Or with custom tag:
make build IMAGE_REPOSITORY=myregistry/telemetrygen-windows IMAGE_TAG=0.121.0
```

## Run locally (Windows container)

```bash
docker run --rm telemetrygen-windows:0.121.0-windows2022
# Override endpoint and service:
docker run --rm telemetrygen-windows:0.121.0-windows2022 telemetrygen.exe traces --otlp-endpoint=host.docker.internal:4317 --otlp-insecure --rate=5 --service=my-service
```

## Use in ECS

The `otel-ecs-ec2-windows/terraform` module can add this as a second container in the collector task (same task = same network, use `localhost:4317`). Enable with `enable_telemetrygen = true` and set `telemetrygen_image` to this image.
