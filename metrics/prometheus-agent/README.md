# Prometheus Agent

The Agent Mode of Prometheus optimizes the remote write use case of Prometheus. 
When running in Agent mode, the querying and alerting are disabled, it focuses on scraping the metrics and send them to the destination.
It is using the same API and discover capabilities as Prometheus, in an efficient way by using customised TSDB WAL that keeps the data that can't be delivered, until the delivery succeeds.
In addition, it is scalable, enabling easier horizontal scalability for ingestion compared to server-mode.

## Prerequisites

### Prometheus Operator 

The Prometheus agent is a Prometheus crd managed by the Promethues operator, meaning the operator must run. 
The agent collects servicemonitors and podmonitors, which are enabled only when using the Prometheus Operator.
You can use any installation of Prometheus Operator, but if you want to install one, you can use the official bundle.

https://github.com/prometheus-operator/prometheus-operator/blob/main/bundle.yaml

Download the bundle.yml file and apply it.

```bash
kubectl create -f bundle.yml
```

#### Prometheus Operator Version
The Prometheus operator must be in version 0.59.0 at least in order to support the agent mode.

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
| EU (Irland)       | https://ingress.coralogix.com/prometheus/v1                          |
| EU2 (Sweden)      | https://ingress.eu2.coralogix.com/prometheus/v1                      |
| US                | https://ingress.coralogix.us/prometheus/v1                           |
| APAC1 (India)     | https://ingress.coralogix.in/prometheus/v1                           |
| APAC2 (Singapore) | https://ingress.coralogixsg.com/prometheus/v1                         |

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
      url: https://prometheus-gateway.coralogix.in/prometheus/api/v1/write
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

## Example App with Pod Selector:

For this example we are going to deploy an app that is exposing metrics

```json
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: example-app
  template:
    metadata:
      labels:
        app: example-app
    spec:
      containers:
      - name: example-app
        image: fabxc/instrumented_app
        ports:
        - name: web
          containerPort: 8080
```

Once we have the application running we need to create a Prometheus podMonitor.

```json
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: example-app
  labels:
    team: frontend
spec:
  selector:
    matchLabels:
      app: example-app
  podMetricsEndpoints:
  - port: web
```

As you can see in this example, the selector is pointing to every pod that has the label “ app: example-app”

## Deplying Node Exporter.

```json
apiVersion: v1
kind: Namespace
metadata:
   name: monitoring
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  labels:
    app.kubernetes.io/component: exporter
    app.kubernetes.io/name: node-exporter
  name: node-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/component: exporter
      app.kubernetes.io/name: node-exporter
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 2
  template:
    metadata:
      labels:
        app.kubernetes.io/component: exporter
        app.kubernetes.io/name: node-exporter
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/path: '/metrics'
        prometheus.io/port: "9100"
    spec:
      hostPID: true
      hostIPC: true
      hostNetwork: true
      enableServiceLinks: false
      containers:
        - name: node-exporter
          image: prom/node-exporter
          imagePullPolicy: IfNotPresent
          securityContext:
            privileged: true
          args:
            - '--path.sysfs=/host/sys'
            - '--path.rootfs=/root'
            - --collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+|var/lib/kubelet/pods/.+)($|/)
            - --collector.netclass.ignored-devices=^(veth.*)$
          ports:
            - containerPort: 9100
              protocol: TCP
          resources:
            limits:
              cpu: 100m
              memory: 100Mi
            requests:
              cpu: 50m
              memory: 50Mi
          volumeMounts:
            - name: sys
              mountPath: /host/sys
              mountPropagation: HostToContainer
            - name: root
              mountPath: /root
              mountPropagation: HostToContainer
      tolerations:
        - operator: Exists
          effect: NoSchedule
      volumes:
        - name: sys
          hostPath:
            path: /sys
        - name: root
          hostPath:
            path: /
```

```json
kubectl create -f <exporter.yml>
```

Once we have the node exporter running in every node, we need to create a Prometheus serviceMonitor so we can scrape the metrics.

```json
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: node-exporter
  name: node-exporter
  namespace: default
spec:
  endpoints:
    - path: /metrics
      port: metrics
  jobLabel: k8s-app
  selector:
    matchLabels:
      app.kubernetes.io/name: prometheus-node-exporter
```

This serviceMonitor will match any service that has label “app.kubernetes.io/name: prometheus-node-exporter”

## Summary

Coralogix Prometheus Agent  allows you to deploy a lightweighted prometheus that will send metrics to Coralogix.
But it will send whatever Prometheus Operator is already scraping. 

In this example we deployed an out of the box Prometheus Operator, Coralogix Prometheus Agent. And then Implemented 2 examples on how to get hosts metrics and an app instrumentation.
