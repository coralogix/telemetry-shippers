# Prometheus Operator Exporters

Most exporters have a ready helm chart ready to be deployed - [Exporters charts](https://github.com/prometheus-community/helm-charts/tree/main/charts)  
be sure to first check there for any exporter.

## Scrape a standalone exporter / container

Prometheus operator has monitors resources to help it generate dynamic scrape config for prometheus.

### PodMonitor
When we want to scrape a single pod we can use the PodMonitor resrouce.  
Example mongodb deployment manifest:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb-exporter
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongodb-exporter
  template:
    metadata:
      labels:
        app: mongodb-exporter
    spec:
      containers:
        - name: mongodb-exporter
          image: percona/mongodb_exporter:2.32
          args: ["--mongodb.uri=mongodb://mongouri:27017/", "--collect-all"]
          ports:
            - containerPort: 9216
              name: metrics
              protocol: TCP
```
Note the `ports` inside the 'containers' this is important for the podmonitor.  
Pod monitor manifest:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: mongodb-exporter
  labels:
    app: mongodb-exporter
spec:
  namespaceSelector:
    matchNames:
    - monitoring
  selector:
    matchLabels:
      app: mongodb-exporter
  podMetricsEndpoints:
  - port: 'metrics'
```

### ServiceMonitor
When we want to scrape a multiple pods using a service we can use the ServiceMonitor resrouce.  
Example fluentbit service:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: fluentbit-service
  labels:
    app.kubernetes.io/name: fluent-bit
  namespace: monitoring
spec:
  selector:
    app.kubernetes.io/instance: fluentbit
    app.kubernetes.io/name: fluent-bit
  ports:
    - name: http
      protocol: TCP
      port: 2020
```
Note the `ports` inside the 'spec', this is important for the servicemonitor.  
Service monitor manifest:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: fluentbit-servicemonitor
  labels:
    name: fluentbit-servicemonitor
spec:
  endpoints:
  - path: /api/v1/metrics/prometheus
    port: http
  namespaceSelector:
    matchNames:
    - monitoring
  selector:
    matchLabels:
      app.kubernetes.io/instance: fluent-bit-http
      app.kubernetes.io/name: fluent-bit
```