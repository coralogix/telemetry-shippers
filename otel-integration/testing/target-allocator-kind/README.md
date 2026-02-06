# Target Allocator Validation on kind

This folder contains a runnable end-to-end validation flow for OpenTelemetry Integration Target Allocator on a local kind cluster.

The flow:
1. Creates a kind cluster.
2. Installs `kube-prometheus-stack` (to create Prometheus CRDs and kubelet ServiceMonitor resources).
3. Installs `otel-integration` with `opentelemetry-agent.targetAllocator.enabled=true`.
4. Enables the collector `debug` exporter with `verbosity: detailed`.
5. Verifies target allocator discovery and kubelet metrics scraping.

## Files

- `Makefile`: automated setup, validation, and cleanup.
- `values-target-allocator.yaml`: otel-integration values with target allocator + debug exporter.
- `values-kube-prometheus-stack.yaml`: lightweight kube-prometheus-stack values for kind (operator + kubelet ServiceMonitor path, no Prometheus/Grafana/Alertmanager workloads).

The otel-integration values intentionally use a custom `fullnameOverride` and RBAC names (`target-allocator-opentelemetry-*`) so this test can run in shared clusters without colliding with existing default release names.

## Prerequisites

- `kind`
- `kubectl`
- `helm`
- `docker`
- `curl`
- `rg`
- `yq`
- `jq`

## Quick Start

Run from this folder:

```bash
make test
```

This runs full setup and validation.

If you want to reuse an already-running kind cluster:

```bash
KIND_CLUSTER_NAME=<cluster-name> KIND_KUBECONFIG=/tmp/kind-<cluster-name> make test
```

## Manual Step-by-Step

```bash
make create-kind-cluster
make install-kube-prometheus-stack
make create-coralogix-secret
make install-otel-integration
make validate
```

## What Validation Checks

- `check-kubelet-servicemonitor`:
  Confirms kube-prometheus-stack created a kubelet `ServiceMonitor`.
- `check-target-allocator-jobs`:
  Port-forwards target allocator service and confirms `/jobs` contains `kubelet`.
- `check-target-allocator-scrape-configs`:
  Confirms `/scrape_configs` contains `kubelet`.
- `check-debug-exporter-config`:
  Reads rendered collector config from ConfigMap and verifies:
  - `exporters.debug.verbosity == detailed`
  - `service.pipelines.metrics.exporters` includes `debug`
- `check-servicemonitor-metrics`:
  Reads agent debug-exporter logs and confirms ServiceMonitor scrape activity and exported metrics are present.

## Notes

- `create-coralogix-secret` uses `CORALOGIX_API_KEY=dummy-private-key` by default.
- To use a real key, run with:

```bash
CORALOGIX_API_KEY=<your-key> make test
```

## Cleanup

```bash
make clean
```

This uninstalls Helm releases (if present) and deletes the kind cluster.
