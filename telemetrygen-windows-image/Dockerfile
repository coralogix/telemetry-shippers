# escape=`
# Multi-stage build: compile telemetrygen for Windows on Linux, then run on Windows servercore.
# For Windows 2022, use `mcr.microsoft.com/windows/servercore:ltsc2022`
ARG TELEMETRYGEN_VERSION=v0.130.0
ARG WIN_BASE_IMAGE=mcr.microsoft.com/windows/servercore:ltsc2019

# Build stage: cross-compile telemetrygen for Windows
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS build
RUN apk add --no-cache git
ARG TELEMETRYGEN_VERSION
WORKDIR /src
RUN git clone --depth 1 --branch ${TELEMETRYGEN_VERSION} https://github.com/open-telemetry/opentelemetry-collector-contrib.git .
# telemetrygen is a separate Go module; build from its directory
WORKDIR /src/cmd/telemetrygen
RUN CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -o telemetrygen.exe .

##
FROM ${WIN_BASE_IMAGE}

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

WORKDIR C:\telemetrygen
COPY --from=build /src/cmd/telemetrygen/telemetrygen.exe ./
COPY scripts/run-logs-and-traces.ps1 ./

# Default OTLP endpoint (override at runtime)
ENV OTEL_EXPORTER_OTLP_ENDPOINT=localhost:4317
ENV OTEL_INSECURE=false
ENV TELEMETRYGEN_RATE=1
ENV TELEMETRYGEN_DURATION=8760h
ENV TELEMETRYGEN_SERVICE=telemetrygen-windows

# Run both logs and traces by default; override with custom CMD to run only one or different args
ENTRYPOINT ["powershell", "-ExecutionPolicy", "Bypass", "-File", "run-logs-and-traces.ps1"]
