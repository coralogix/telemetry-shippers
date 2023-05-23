# OpenTelemetry Collector Helm Chart

## Description

Temporary fork of [OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector) to add support for Windows containers.

Working on the support upstream. See https://github.com/open-telemetry/opentelemetry-helm-charts/pull/792

## Installation

```
helm repo add coralogix-charts-virtual https://cgx.jfrog.io/artifactory/coralogix-charts-virtual
helm repo update
helm upgrade --install otel-coralogix-agent-windows coralogix-charts-virtual/opentelemetry-coralogix-windows \
  -f values.yaml
```

## Docker image

To build OpenTelemetry Collector Contrib use [the Dockerfile available in here](https://github.com/coralogix/telemetry-shippers/tree/master/otel-agent/otel-collector-windows-image).
