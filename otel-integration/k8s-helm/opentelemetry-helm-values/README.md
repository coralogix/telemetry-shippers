## OpenTelemetry Helm Values

Pre-configured values files for deploying the upstream OpenTelemetry Collector Helm chart with Coralogix integration.

### Files
- `agent-values.yaml` - Basic agent configuration (DaemonSet)
- `cluster-collector-values.yaml` - Basic cluster collector configuration (Deployment)
- `agent-values-apm.yaml` - **APM-enabled agent** with traces, span metrics, sampling
- `cluster-collector-values-apm.yaml` - **APM-enabled cluster collector** with full Infrastructure Explorer correlation

### APM-Infrastructure Correlation

**Key Discovery**: APM traces correlate with Infrastructure Explorer through `process.tags` (not `resource.attributes`).

**Required Attributes for Correlation**:
- `k8s_cluster_name` / `k8s.cluster.name`
- `k8s_pod_name` / `k8s.pod.name`
- `k8s_namespace_name` / `k8s.namespace.name`

**How It Works**:
1. User selects pod in Infrastructure Explorer
2. Coralogix queries traces using: `process.tags.k8s_pod_name:"pod-name"`
3. All telemetry types (logs, metrics, traces, events) use same correlation keys
4. Unified view across application and infrastructure layers

### Custom App Metrics Integration

**Method 1: Prometheus Annotations**

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

**Method 2: OTLP Direct**
- Applications send metrics via OTLP (port 4317/4318)
- Automatic Kubernetes attribute enrichment via `k8sattributes` processor

### Quick Start

```bash
# Deploy APM-enabled agent
helm install otel-agent open-telemetry/opentelemetry-collector \
  --set mode=daemonset \
  -f agent-values-apm.yaml

# Deploy APM-enabled cluster collector
helm install otel-cluster-collector open-telemetry/opentelemetry-collector \
  --set mode=deployment \
  -f cluster-collector-values-apm.yaml
```

### Configuration

**Required Environment Variables**:
- `CORALOGIX_PRIVATE_KEY` - Your Coralogix private key
- `CORALOGIX_DOMAIN` - Your Coralogix domain

**Update Values**:
- Change `domain` in exporters to your Coralogix domain
- Change `k8s.cluster.name` in `resource/metadata` processor to your cluster name
