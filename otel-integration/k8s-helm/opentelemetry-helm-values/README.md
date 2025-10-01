## OpenTelemetry Helm values

- `agent-values.yaml`: values.yaml for `DaemonSet`
- `cluster-collector-values.yaml`: values.yaml for `Deployment`

### How to use with the OpenTelemetry Collector Helm chart

Install the agent and collector in order. Choose ONE method for the private key: Kubernetes Secret (recommended) OR shell env.

### Step 1
```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
```

### Step 2
```bash
kubectl create namespace coralogix-otel --dry-run=client -o yaml | kubectl apply -f -
```

### Step 3 (create Secret)
```bash
kubectl -n coralogix-otel create secret generic coralogix-creds \
  --from-literal=CORALOGIX_PRIVATE_KEY="<your-private-key>"
```

### Step 4 (install cluster collector)
```bash
# Cluster collector (deployment mode)
helm upgrade --install coralogix-cluster-collector open-telemetry/opentelemetry-collector \
  -n coralogix-otel -f cluster-collector-values.yaml \
  --set image.repository="otel/opentelemetry-collector-k8s" \
  --set mode=deployment \
  --set config.exporters.coralogix.domain="<your-coralogix-domain>" \
  --set extraEnvs[0].name=CORALOGIX_PRIVATE_KEY \
  --set extraEnvs[0].valueFrom.secretKeyRef.name=coralogix-creds \
  --set extraEnvs[0].valueFrom.secretKeyRef.key=CORALOGIX_PRIVATE_KEY
```

### Step 5 (install agent)
```bash
# Agent (daemonset mode)
helm upgrade --install coralogix-agent open-telemetry/opentelemetry-collector \
  -n coralogix-otel -f agent-values.yaml \
  --set image.repository="otel/opentelemetry-collector-k8s" \
  --set mode=daemonset \
  --set config.exporters.coralogix.domain="<your-coralogix-domain>" \
  --set extraEnvs[0].name=CORALOGIX_PRIVATE_KEY \
  --set extraEnvs[0].valueFrom.secretKeyRef.name=coralogix-creds \
  --set extraEnvs[0].valueFrom.secretKeyRef.key=CORALOGIX_PRIVATE_KEY
```

#### Note: alternate to Secret for Steps 4–5:
```bash
export CORALOGIX_PRIVATE_KEY="<your-private-key>"

helm upgrade --install coralogix-cluster-collector open-telemetry/opentelemetry-collector \
  -n coralogix-otel -f cluster-collector-values.yaml \
  --set image.repository="otel/opentelemetry-collector-k8s" \
  --set mode=deployment \
  --set config.exporters.coralogix.domain="<your-coralogix-domain>"

helm upgrade --install coralogix-agent open-telemetry/opentelemetry-collector \
  -n coralogix-otel -f agent-values.yaml \
  --set image.repository="otel/opentelemetry-collector-k8s" \
  --set mode=daemonset \
  --set config.exporters.coralogix.domain="<your-coralogix-domain>"
```

 

