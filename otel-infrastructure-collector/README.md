# OpenTelemetry Infrastructure Collector

The OpenTelemetry collector offers a vendor-agnostic implementation of how to receive, process and export telemetry data. 
In this chart, the collector will be deployed as a single replica deployment. 



## Coralogix's Endpoints 

Depending on your region, you need to configure correct Coralogix endpoint. Here are the available Endpoints:

| Region  | Traces Endpoint                          | Metrics Endpoint                     | Logs Endpoint                     |
|---------|------------------------------------------|------------------------------------- | --------------------------------- |
| USA1    | `otel-traces.coralogix.us:443`      | `otel-metrics.coralogix.us:443`      | `otel-logs.coralogix.us:443`      |
| APAC1   | `otel-traces.app.coralogix.in:443`  | `otel-metrics.app.coralogix.in:443`  | `otel-logs.app.coralogix.in:443`  | 
| APAC2   | `otel-traces.coralogixsg.com:443`   | `otel-metrics.coralogixsg.com:443`   | `otel-logs.coralogixsg.com:443`   |
| EUROPE1 | `otel-traces.coralogix.com:443`     | `otel-metrics.coralogix.com:443`     | `otel-logs.coralogix.com:443`     |
| EUROPE2 | `otel-traces.eu2.coralogix.com:443` | `otel-metrics.eu2.coralogix.com:443` | `otel-logs.eu2.coralogix.com:443` |

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