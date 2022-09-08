# OpenTelemetry Agent
The OpenTelemetry collector offers a vendor-agnostic implementation of how to receive, process and export telemetry data. 
In this chart, the collector will be deployed as a daemonset, meaning the collector will run as an `agent` on each node.
It supports only the traces pipeline, and configured with the Coralogix exporter.
The supported receivers are Otel, Zipkin and Jaeger. 

#### Please read the [main README](https://github.com/coralogix/eng-integrations/blob/master/README.md) before following this chart installation.

## Installation
In order to update the environment variables, please create a new yaml file and include *all* of the following envs inside:
There is an override.yaml file that can be copied under the `examples` directory.

```yaml
---
#override.yaml:
opentelemetry-collector:
  extraEnvs:
  - name: CORALOGIX_PRIVATE_KEY
    valueFrom:
      secretKeyRef:
        name: integrations-privatekey
        key: PRIVATE_KEY
  - name: APP_NAME
    value: production # Can be any other static value
  - name: KUBE_NODE_NAME
    valueFrom:
      fieldRef:
        apiVersion: v1
        fieldPath: spec.nodeName
  - name: CORALOGIX_TRACES_ENDPOINT
    value: # <The Coralogix traces ingress endpoint, must be configured for sending traces>
  - name: CORALOGIX_METRICS_ENDPOINT
    value: # <The Coralogix metrics ingress endpoint, must be configured for sending metrics>
```

```bash
helm upgrade otel-coralogix-agent coralogix-charts-virtual/opentelemetry-coralogix \
  --install --namespace=<your-namespace> \
  --create-namespace \
  -f override.yaml
```

## Send your metrics to Coralogix
By default, the Prometheus receiver is enabled, it collects metrics on the agent itself, and they are sent to Coralogix. 
In order to disable it, in addition to the `extraEnvs` section, add the following section to your override.yaml:
*** It will disable the prometheus receiver and the coralogix exporter from the metrics pipeline.
 
```yaml
---
#override.yaml:
opentelemetry-collector:
  service:
    pipelines:
      metrics:
        exporters:
        - logging
        processors:
        - memory_limiter
        - batch
        receivers:
        - otlp
```  

## Monitoring the agent
If you have Prometheus configured, with the Prometheus operator, it is recommended to enable the podMonitor and the prometheusRules offered by this chart. 
In order to enable it By enabling it, the metrics port must be enabled, the podmonitor must be enabled, and the prometheusrules must be enabled [if desired].

## Coralogix Endpoints

| Region  | Traces Endpoint                               | Metrics Endpoint	
|---------|-----------------------------------------------|-----------------------------------------------
| USA1	  | `tracing-ingress.coralogix.us:9443`           | `otel-metrics.coralogix.us:443`	
| APAC1   | `tracing-ingress.app.coralogix.in:9443`       | `otel-metrics.coralogix.in:443`
| APAC2   | `tracing-ingress.coralogixsg.com:9443`        | `otel-metrics.coralogixsg.com:443`
| EUROPE1 | `tracing-ingress.coralogix.com:9443`          | `otel-metrics.coralogix.com:443`
| EUROPE2 | `tracing-ingress.eu2.coralogix.com:9443`      | `otel-metrics.eu2.coralogix.com:443`

---
**NOTE**

The Open Telemetry Coralogix exporter requires the Coralogix private key.
#### Please see the note in the [main README](https://github.com/coralogix/eng-integrations/blob/master/README.md) in order to create the required secret.
---
