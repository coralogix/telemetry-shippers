# Prometheus Operator

Installs the kube-prometheus stack to provide easy to operate end-to-end Kubernetes cluster monitoring with Prometheus and exporters using the Prometheus Operator.
The included chart provides:

- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator) - The Prometheus Operator provides Kubernetes native deployment and management of Prometheus and related monitoring components.
- [Prometheus](https://prometheus.io/) The open source monitoring toolkit.
- [Prometheus node-exporter](https://github.com/prometheus/node_exporter) - Prometheus exporter for hardware and OS metrics exposed by *NIX kernels.
- [Prometheus Adapter for Kubernetes Metrics APIs](https://github.com/kubernetes-sigs/prometheus-adapter) - Prometheus adapter leverage the metrics collected by Prometheus to allow for autoscaling based on metrics.
- [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics) - A service that listens to the Kubernetes API server and generates metrics about the state of the objects.

## Prerequisites

### Secret Key

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

https://coralogix.com/docs/coralogix-endpoints/.

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
helm upgrade --install prometheus-coralogix coralogix-charts-virtual/prometheus-operator-coralogix \
  --namespace=monitoring \
  -f values.yaml
```

## Removal

```bash
helm uninstall prometheus-coralogix \
--namespace=monitoring
```

# Dependencies

This chart uses [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) chart.

<!---
since version 0.0.2 the Chart was updated to use prometheus-kube-stack v45.30.0 due to deprecation of autoscaling/v1beta object in Kubernetes v1.23+
Additionally in version 45.30.0 there is a bug with recording rules labels hack thus we needed to upgrade to 45.31.* to resolve this (https://github.com/prometheus-community/helm-charts/pull/3400)
-->

## Metric Labels

To add labels to metrics via the Prometheus configuration, you can use the `externalLabels` key in the values.yaml file as shown below:

```yaml
kube-prometheus-stack:
  prometheus:
    prometheusSpec:
      externalLabels:
        cluster: MyCluster
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
