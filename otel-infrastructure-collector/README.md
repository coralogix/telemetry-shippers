# OpenTelemetry Infrastructure Collector

The OpenTelemetry collector offers a vendor-agnostic implementation of how to receive, process and export telemetry data.
In this chart, the collector will be deployed as a single replica deployment.

## Coralogix's Endpoints

Depending on your region, you need to configure correct Coralogix endpoint. Here are the available Endpoints:

https://coralogix.com/docs/coralogix-endpoints/.

Example configuration:

```yaml
#values.yaml:
---
global:
  traces:
    endpoint: "<traces-endpoint-here>"
  metrics:
    endpoint: "<metrics-endpoint-here>"
  logs:
    endpoint: "<logs-endpoint-here>"
```
