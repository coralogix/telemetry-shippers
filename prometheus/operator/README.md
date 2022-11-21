# Prometheus Operator

Installs the kube-prometheus stack to provide easy to operate end-to-end Kubernetes cluster monitoring with Prometheus and exporters using the Prometheus Operator.
The included chart provides:

- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator) - The Prometheus Operator provides Kubernetes native deployment and management of Prometheus and related monitoring components.
- [Prometheus](https://prometheus.io/) The open source monitoring toolkit.
- [Prometheus node-exporter](https://github.com/prometheus/node_exporter) - Prometheus exporter for hardware and OS metrics exposed by *NIX kernels.
- [Prometheus Adapter for Kubernetes Metrics APIs](https://github.com/kubernetes-sigs/prometheus-adapter) - Prometheus adapter leverage the metrics collected by Prometheus to allow for autoscaling based on metrics.
- [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics) - A service that listens to the Kubernetes API server and generates metrics about the state of the objects.


## Endpoints

### Coralogix's Endpoints 

Depending on your region, you need to configure correct Coralogix endpoint. Here are the available Endpoints:

| Region            | Prometheus remoteWrite Endpoint     | 
|-------------------|------------------------------------------------------------------------|
| US                | `https://prometheus-gateway.coralogix.us/prometheus/api/v1/write`      |
| APAC1 (India)     | `https://prometheus-gateway.coralogix.in/prometheus/api/v1/write`      |
| APAC2 (Singapore) | `https://prometheus-gateway.coralogixsg.com/prometheus/api/v1/write`   |
| EUROPE1 (Irland)  | `https://prometheus-gateway.coralogix.com/prometheus/api/v1/write`     |
| EUROPE2 (Sweden)  | `https://prometheus-gateway.eu2.coralogix.com/prometheus/api/v1/write` |

Example configuration:
```yaml
#values.yaml:
---
kube-prometheus-stack:
  prometheus: 
    prometheusSpec: 
      remoteWrite:
        - url: 'https://prometheus-gateway.coralogix.com/prometheus/api/v1/write'
          name: 'crx'
          remoteTimeout: 120s
          bearerToken: 'xxx' 
```  
Using secret as bearer token:

Secret:
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
values:
```yaml
kube-prometheus-stack:
  prometheus: 
    prometheusSpec: 
      secrets: ['coralogix-keys']
      remoteWrite:
        ## the coralogix account domain url
        - url: 'https://prometheus-gateway.coralogix.com/prometheus/api/v1/write'
          name: 'crx'
          remoteTimeout: 120s
          ## the coralogix account privatekey secret and name.
          bearerTokenFile: '/etc/prometheus/secrets/coralogix-keys/PRIVATE_KEY' 
  grafana:
    enabled: false
  alertmanager:
    enabled: false
```
## Installation

```bash
helm upgrade --install prometheus-coralogix coralogix-charts-virtual/prometheus-coralogix \
  -f values.yaml
```

# Dependencies

This chart uses [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) chart.
