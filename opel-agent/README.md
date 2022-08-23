# OpenTelemetry Agent
The OpenTelemetry collector offers a vendor-agnostic implementation of how to receive, process and export telemetry data. 
In this chart, the collector will be deployed as a daemonset, meaning the collector will run as an agent on each node.
It supports only the traces pipeline, and configured with the Coralogix exporter.
The supported receivers are Otel, Zipkin and Jaeger. 

## Installation
```bash
helm upgrade otel-coralogix-agent coralogix-charts-virtual/opentelemetry-agent \
  --install --namespace=<your-namespace> \
  --create-namespace \
  --set "opentelemetry-collector.APP_NAME=<desired-app-name>"
  --set "opentelemetry-collector.CORALOGIX_ENDPOINT=<your-traces-endpoint>"
```

## Monitoring the agent
If you have Prometheus configured, with the Prometheus operator, it is recommended to enable the servicemonitor and the prometheusrules offered by this chart. By enabling it, a servicemonitor for the agent will be created, and some default Prometheus alerts will be created.    

## Coralogix Endpoints

| Region  | Traces Endpoint
|---------|------------------------------------------|
| USA1	  | `tracing-ingress.coralogix.us`           |
| APAC1   | `tracing-ingress.app.coralogix.in`       |
| APAC2   | `tracing-ingress.coralogixsg.com`        |
| EUROPE1 | `tracing-ingress.coralogix.com`          |
| EUROPE2 | `tracing-ingress.eu2.coralogix.com`      |

---
**NOTE**

The Open Telemetry Coralogix exporter requires the Coralogix private key. Therefore the following secret must be created: 

* The `private key` appears under 'Data Flow' --> 'API Keys' in Coralogix UI:
![logo](https://github.com/coralogix/eng-integrations/blob/master/opel-agent/images/dataflow.jpg?raw=true)
![logo](https://github.com/coralogix/eng-integrations/blob/master/opel-agent/images/key.jpg?raw=true)


```bash
kubectl create secret generic coralogix-otel-privatekey \
  -n <the-namespace-of-the-release> \
  --from-literal=PRIVATE_KEY=<coralogix-private-key>
```

The created secret should look like this:
```yaml
apiVersion: v1
data:
  PRIVATE_KEY: <encrypted-private-key>
kind: Secret
metadata:
  name: coralogix-otel-privatekey
  namespace: <the-release-namespace>
type: Opaque
```

---