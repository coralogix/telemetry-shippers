# Changelog

## OpenTelemtry-Integration

### v0.0.8 / 2023-08-11

* [CHORE] Upgrading upstream chart. (v0.69.0)

### v0.0.7 / 2023-08-11

* [FEATURE] Align `cx.otel_integration.name` with the new internal requirements

### v0.0.6 / 2023-08-08

* [CHORE] Bump Coralogix OpenTelemetry chart to `0.68.0`
* [FEATURE] Make `k8s.node.name` label the target node for Kubernetes node info metric

### v0.0.5 / 2023-08-04

* [FIX] Fix `kube-event` transfrom processor configuration to correctly filter log body keys

### v0.0.4 / 2023-08-03

* [FEATURE] Add cluster metrics related to allocatable resources (CPU, memory)
* [CHORE] Remove unused `cx.otel_integration.version` attribute
* [CHORE] Remove unused `enabled` parameter on `kube-state-metrics` config

### v0.0.3 / 2023-08-02

* [CHORE] Bump Coralogix OpenTelemetry chart to `0.67.0`

### v0.0.2 / 2023-08-02

* [FEATURE] Add `k8s.node.name` resource attribute to cluster collector
* [FEATURE] Override detection for cloud provider detectors
* [BUG] Fix ports configuration

### v0.0.1 / 2023-07-21

* [FEATURE] Add new chart
