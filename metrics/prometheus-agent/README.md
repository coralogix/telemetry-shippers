# Prometheus Agent

The Agent Mode of Prometheus optimizes the remote write use case of Prometheus. 
When running in Agent mode, the querying and alerting are disabled, it focuses on scraping the metrics and send them to the destination.
It is using the same API and discover capabilities as Prometheus, in an efficient way by using customised TSDB WAL that keeps the data that can't be delivered, until the delivery succeeds.
In addition, it is scalable, enabling easier horizontal scalability for ingestion compared to server-mode.

## Prerequisites

### Prometheus Operator 

The Prometheus Agent collects servicemonitors and podmonitors, which are enabled only when using the Prometheus Operator.

###  Secret Key

Follow the [private key docs](https://coralogix.com/docs/private-key/) tutorial to obtain your secret key tutorial to obtain your secret key.

Prometheus Agent require a `secret` called `coralogix-keys` with the relevant `private key` under a secret key called `PRIVATE_KEY`, inside the `same namespace` that the chart is installed in.


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

### Endpoints

### Coralogix's Endpoints 

Depending on your region, you need to configure correct Coralogix endpoint. Here are the available Endpoints:

| Cluster (Region)  | Remote_write URL                                                     |
|-------------------|----------------------------------------------------------------------|
| EU (Irland)       | https://prometheus-gateway.coralogix.com/prometheus/api/v1/write |
| EU2 (Sweden)      | https://prometheus-gateway.eu2.coralogix.com/prometheus/api/v1/write |
| US                | https://prometheus-gateway.coralogix.us/prometheus/api/v1/write    |
| APAC1 (India)     | https://prometheus-gateway.coralogix.in/prometheus/api/v1/write     |
| APAC2 (Singapore) | https://prometheus-gateway.coralogixsg.com/prometheus/api/v1/write   |

## Installation

In order to override the Coralogix url, a new file must be created, including the following section:

```yaml
---
# override.yaml:
prometheus:
  prometheusSpec:
    remoteWrite:
    - authorization:
        credentials:
          name: coralogix-keys
          key: PRIVATE_KEY
      name: prometheus-agent-coralogix
      queueConfig:
        capacity: 2500
        maxSamplesPerSend: 1000
        maxShards: 200
      remoteTimeout: 120s
      url: https://prometheus-gateway.coralogix.in/prometheus/api/v1/write
```

```bash
helm upgrade prometheus-agent coralogix-charts-virtual/prometheus-agent-coralogix \
  --install \
  --namespace=<your-namespace> \
  --create-namespace \
  -f override.yaml
```
