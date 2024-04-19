# Prometheus Agent

The Agent Mode of Prometheus optimizes the remote write use case of Prometheus.
When running in Agent mode, the querying and alerting are disabled, it focuses on scraping the metrics and send them to the destination.
It is using the same API and discover capabilities as Prometheus, in an efficient way by using customised TSDB WAL that keeps the data that can't be delivered, until the delivery succeeds.
In addition, it is scalable, enabling easier horizontal scalability for ingestion compared to server-mode.

Prometheus Agent allows you to deploy a lightweighted prometheus that will send metrics to Coralogix.
But it will send whatever Prometheus Operator is already scraping.

## Prerequisites

### Prometheus Operator

The Prometheus agent is a Prometheus crd managed by the Promethues operator, meaning the operator must run.
If you need to install Prometheus Operator, here is the link to our docs:
https://github.com/coralogix/telemetry-shippers/tree/master/metrics/prometheus/operator

The agent collects servicemonitors and podmonitors, which are enabled only when using the Prometheus Operator.

#### Prometheus Operator Version

The Prometheus operator must be in version 0.59.0 at least in order to support the agent mode.

### Secret Key

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

https://coralogix.com/docs/coralogix-endpoints/.

## Installation

First make sure to add our Helm charts repository to the local repos list with the following command:

```bash
helm repo add coralogix-charts-virtual https://cgx.jfrog.io/artifactory/coralogix-charts-virtual
```

In order to get the updated Helm charts from the added repository, please run:

```bash
helm repo update
```

Before installing the chart, in order to override the Coralogix url, a new file must be created, including the following section:

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
      url: https://ingress.coralogix.com/prometheus/v1
```

Install the chart:

```bash
helm upgrade prometheus-agent coralogix-charts-virtual/prometheus-agent-coralogix \
  --install \
  --namespace=<your-namespace> \
  --create-namespace \
  -f override.yaml
```

## Recommendations

By default, the Prometheus agent is using ephemeral volumes which is not suitable for a production environment.

For the production environment is highly recommended you define a persistent volume to avoid data loss between restarts, to do that you can use the specification available on the values file.

> :information_source: Beaware if you don not specify the `storageClassName` Kubernetes will use the default storage class available on the cluster.

```yaml
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi

```

## Metric Labels

To add labels to metrics via the Prometheus configuration, you can use the `externalLabels` key in the values.yaml file as shown below:

```yaml
prometheus:
  prometheusSpec:
    externalLabels:
      cluster: MyCluster
```
