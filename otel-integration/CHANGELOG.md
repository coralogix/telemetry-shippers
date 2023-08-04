# Changelog

## OpenTelemtry-Integration

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
