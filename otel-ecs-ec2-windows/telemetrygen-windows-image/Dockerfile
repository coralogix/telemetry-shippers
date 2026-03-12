# Build telemetrygen for Windows (cross-compile from Linux, then run on Windows Server Core 2022).
# Use same version as collector (0.121.0) for compatibility.
ARG TELEMETRYGEN_VERSION=0.121.0

FROM --platform=linux/amd64 golang:1.21-alpine AS build
ARG TELEMETRYGEN_VERSION
RUN apk add --no-cache git
WORKDIR /src
# Clone contrib at the same version as the collector; build only telemetrygen for Windows.
RUN git clone --depth 1 --branch "v${TELEMETRYGEN_VERSION}" https://github.com/open-telemetry/opentelemetry-collector-contrib.git .
WORKDIR /src/cmd/telemetrygen
RUN CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -o telemetrygen.exe .

FROM mcr.microsoft.com/windows/servercore:ltsc2022
SHELL ["cmd", "/S", "/C"]
COPY --from=build /src/cmd/telemetrygen/telemetrygen.exe /telemetrygen.exe
# Default: generate traces to localhost:4317 (collector in same task). Override with full command.
ENTRYPOINT ["telemetrygen.exe"]
CMD ["traces", "--otlp-endpoint=localhost:4317", "--otlp-insecure", "--rate=10", "--duration=inf", "--service=telemetrygen-windows"]
