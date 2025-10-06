## OpenTelemetry Collector values:

This document explains the intent of key sections in the values files and provides a validation checklist.

Files:
- `agent-values.yaml` (run with `--set mode=daemonset`)
- `cluster-collector-values.yaml` (run with `--set mode=deployment`)

### agent-values.yaml (DaemonSet agent)
- command: use `otelcol-contrib` binary.
- presets: `hostMetrics` and `kubernetesAttributes` enabled for node metrics and K8s metadata.
- exporters: `coralogix` (main), `coralogix/resource_catalog` (inventory logs), optional `debug`.
- extensions: `health_check` on `${env:MY_POD_IP}:13133`, local `pprof` and `zpages`.
- processors: batching, Kubernetes enrichment, resource detection, transforms, memory limiting.
- receivers: `hostmetrics`, `otlp` (4317/4318), Jaeger/Zipkin compatibility.
- pipelines: metrics → coralogix; traces/logs via OTLP; resource catalog logs via dedicated pipeline.
- resources: modest default requests/limits for node agents.
- volumes: read-only `/hostfs` for hostmetrics.
- env: `K8S_NODE_NAME` for association.

### cluster-collector-values.yaml (Deployment cluster collector)
- command: `otelcol-contrib`.
- replicaCount: `1` for cluster-wide operation.
- exporters: `coralogix`, `coralogix/resource_catalog`, optional `debug`.
- extensions: similar to agent.
- processors: batching, memory limiting, K8s enrichment, resource detection, workflow filtering, transforms.
- receivers: `k8sobjects/resource_catalog` (watches/pulls K8s objects), `otlp`.
- pipelines: `logs/resource_catalog` → `coralogix/resource_catalog`; metrics/logs/traces → `coralogix`.
- resources: higher than agent.
- serviceAccount/env: dedicated SA; `K8S_NODE_NAME` provided.
