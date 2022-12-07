# Prometheus Operator



Installs the kube-prometheus stack to provide easy to operate end-to-end Kubernetes cluster monitoring with Prometheus and exporters using the Prometheus Operator.
The included chart provides:

- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator) - The Prometheus Operator provides Kubernetes native deployment and management of Prometheus and related monitoring components.
- [Prometheus](https://prometheus.io/) The open source monitoring toolkit.
- [Prometheus node-exporter](https://github.com/prometheus/node_exporter) - Prometheus exporter for hardware and OS metrics exposed by *NIX kernels.
- [Prometheus Adapter for Kubernetes Metrics APIs](https://github.com/kubernetes-sigs/prometheus-adapter) - Prometheus adapter leverage the metrics collected by Prometheus to allow for autoscaling based on metrics.
- [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics) - A service that listens to the Kubernetes API server and generates metrics about the state of the objects.


## Prerequisites

###  Secret Key

Follow the [private key docs](https://coralogix.com/docs/private-key/) tutorial to obtain your secret key tutorial to obtain your secret key.

Prometheus operator require a `secret` called `coralogix-keys` with the relevant `private key` under a secret key called `PRIVATE_KEY`, inside the `same namespace` that the chart is installed in.


```bash
kubectl create secret generic coralogix-keys \
  --from-literal=PRIVATE_KEY=<private-key>
```

The created secret should look like this:
```yaml
apiVersion: v1
data:
  PRIVATE_KEY: <encrypted-private-key>
kind: Secret
metadata:
  name: coralogix-keys
  namespace: <the-release-namespace>
type: Opaque 
```

### Coralogix's Endpoints 

Depending on your region, you need to configure correct Coralogix endpoint. Here are the available Endpoints:

| Region            | Prometheus remoteWrite Endpoint     | 
|-------------------|------------------------------------------------------------------------|
| US1 (Ohio)                | `https://prometheus-gateway.coralogix.us/prometheus/api/v1/write`      |
| APAC1 (Mumbai)     | `https://prometheus-gateway.coralogix.in/prometheus/api/v1/write`      |
| APAC2 (Singapore) | `https://prometheus-gateway.coralogixsg.com/prometheus/api/v1/write`   |
| EUROPE1 (Ireland)  | `https://prometheus-gateway.coralogix.com/prometheus/api/v1/write`     |
| EUROPE2 (Stockholm)  | `https://prometheus-gateway.eu2.coralogix.com/prometheus/api/v1/write` |

## Example configuration:

### Using secret as bearer token (recommended):

values:
```yaml
#values.yaml:
---
global:
  endpoint: "<remote_write_endpoint>"
```

### Using plain-text bearer token (old way):
```yaml
#values.yaml:
---
kube-prometheus-stack:
  prometheus: 
    prometheusSpec: 
      secrets: [] ## important when not using a secret
      remoteWrite:
        - url: '<remote_write_endpoint>'
          name: 'crx'
          remoteTimeout: 120s
          bearerToken: '<private_key>' 
```  
## Installation

```bash
helm upgrade --install prometheus-coralogix coralogix-charts-virtual/prometheus-coralogix \
  -f values.yaml
```

# Dependencies

This chart uses [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) chart.
