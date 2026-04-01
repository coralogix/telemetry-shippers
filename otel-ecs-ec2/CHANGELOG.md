# Changelog

### 0.0.15 / 2026-04-01

* [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.6`.

#### Changes from opentelemetry-collector 0.130.6:
- [Feat] Add target allocator `allocationFallbackStrategy`, `probeSelector`, and `probeNamespaceSelector` chart values for Prometheus CR rendering.

### 0.0.14 / 2026-03-31

* [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.5`.

#### Changes from opentelemetry-collector 0.130.5:
- [Feat] For `distribution` `standalone` and `macos`, prepend `cx.application.name` and `cx.subsystem.name` to Coralogix exporter `application_name_attributes` and `subsystem_name_attributes` (before `service.namespace` / `service.name`) so presets such as `filelogMulti` and `prometheusMulti` drive Application/Subsystem when set.

### 0.0.13 / 2026-03-20

* [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.4`.
* [CHANGE] Add `samplesPerSecond` to values.yaml with `20` by default

### 0.0.12 / 2026-03-19

* [CHANGE] Enable Coralogix exporter for `opentelemetry-ebpf-profiler`. This is used to generate another configuration for profiling in the form of a ConfigMap.

### 0.0.11 / 2026-03-12

* [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.1`.

### 0.0.10 / 2026-03-12

* [CHANGE] Bump Coralogix OTEL collector image to `coralogixrepo/coralogix-otel-collector:v0.5.9` (aligned in Helm values, example manifest, Terraform `image_version` default, and Makefile `CDOT_IMAGE` default).

### 0.0.9 / 2026-02-17

* [CHANGE] Bump Coralogix OTEL collector image to `coralogixrepo/coralogix-otel-collector:v0.5.8` (aligned in Helm values, example manifest, Terraform `image_version` default, and Makefile `CDOT_IMAGE` default).

### 0.0.8 / 2026-01-16

* [FEATURE] ECS attributes processor now supports spans and profiles.
* [FEATURE] Add eBPF profiler preset, disabled by default (`presets.ebpfProfiler.enabled=false`).

### 0.0.7 / 2026-01-06

* [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.128.1`.

### 0.0.6 / 2026-01-02

* [CHANGE] Bump Coralogix OTEL collector image to `coralogixrepo/coralogix-otel-collector:v0.5.7` (aligned in Helm values, example manifest, and Terraform `image_version` default).

### 0.0.5 / 2025-11-25

* [CHANGE] Bump Coralogix OTEL collector image to `coralogixrepo/coralogix-otel-collector:v0.5.6` (aligned in Helm values, example manifest, and Terraform `image_version` default).

### 0.0.4 / 2025-10-22

* [CHANGE] Bump Coralogix OTEL collector image to `coralogixrepo/coralogix-otel-collector:v0.5.2` (aligned in Helm values, example manifest, and Terraform `image_version` default).

## ecs-ec2-integration

### 0.0.3 / 2025-09-09

* [CHANGE] Bump Coralogix OTEL collector image to `coralogixrepo/coralogix-otel-collector:v0.5.1` (aligned in Helm values, example manifest, and Terraform `image_version` default).

### 0.0.2 / 2025-08-28

* [FEATURE] Enable resource reduction preset by default to reduce metrics/resource cardinality (`presets.reduceResourceAttributes.enabled=true`).
* [CHANGE] Switch default agent image to Coralogix distribution: `coralogixrepo/coralogix-otel-collector:v0.5.0`.
* [FEATURE] Allow users to enable multiline log recombination via `presets.ecsLogsCollection.multiline` (e.g., `lineStartPattern`, `omitPattern`).
