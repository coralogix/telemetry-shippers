# Telemetrygen Windows Docker Image

Windows Docker image for [telemetrygen](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/cmd/telemetrygen) from OpenTelemetry Collector Contrib. It is built and run in the same way as the [otel-collector-windows-image](../otel-collector-windows-image) in this repo.

By default the image runs **both logs and traces** generators: the logs generator runs in the background and the traces generator runs in the foreground so the container stays up.

## Build dependencies

1. `docker buildx`

## Building the image (macOS / Linux)

1. Create a buildx builder (if you don’t have one):

   ```bash
   docker buildx create --name img-builder --use --driver docker-container
   ```

2. Build for your Windows version:

   ```bash
   make win2019   # Windows Server 2019
   make win2022   # Windows Server 2022
   ```

Optional overrides:

- `IMAGE_REPOSITORY` – image name (default: `telemetrygen-windows`)
- `IMAGE_TAG` – tag (default: `win2019` or `win2022` from targets)
- `TELEMETRYGEN_VERSION` – contrib tag to build
- `POST_BUILD=--push` – push after build

## Running the image

Default behavior: send both logs and traces to the OTLP endpoint.

**Environment variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP gRPC endpoint (host:port) | `localhost:4317` |
| `OTEL_INSECURE` | Set to `true` or `1` for plaintext gRPC | `false` |
| `TELEMETRYGEN_RATE` | Rate (e.g. spans/logs per second) | `1` |
| `TELEMETRYGEN_DURATION` | Run duration (Go duration, e.g. `60s`, `5m`, `8760h`) | `8760h` |
| `TELEMETRYGEN_SERVICE` | Service name in generated telemetry | `telemetrygen-windows` |

**Example (insecure, custom endpoint):**

```powershell
docker run --rm -e OTEL_EXPORTER_OTLP_ENDPOINT=collector:4317 -e OTEL_INSECURE=true telemetrygen-windows:win2022
```

**Run only traces (override entrypoint):**

```powershell
docker run --rm -e OTEL_EXPORTER_OTLP_ENDPOINT=collector:4317 --entrypoint "C:\telemetrygen\telemetrygen.exe" telemetrygen-windows:win2022 traces --otlp-insecure --duration=8760h
```

**Run only logs:**

```powershell
docker run --rm -e OTEL_EXPORTER_OTLP_ENDPOINT=collector:4317 --entrypoint "C:\telemetrygen\telemetrygen.exe" telemetrygen-windows:win2022 logs --otlp-insecure --duration=8760h
```

Images are built for the `windows/amd64` platform only.
