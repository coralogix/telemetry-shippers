# Changelog

### 0.0.22 / 2026-04-29

* [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.17`.

#### Changes from opentelemetry-collector 0.130.17:
- [Fix] Convert `supervisor.collector` wrapped collector logs into first-class log records when `presets.logsCollection.includeCollectorLogs` is enabled, preserving the nested collector severity, body, component attributes, and resource attributes instead of leaving them embedded in the outer `msg` string.

### 0.0.21 / 2026-04-27

* [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.16`.

#### Changes from opentelemetry-collector 0.130.16:
- [Feat] Use `connection` pod association for profiling k8sattributes processor

#### Changes from opentelemetry-collector 0.130.15:
- [Fix] Use `syslog_parser` for macOS system log parsing logic.

### 0.0.20 / 2026-04-22

* [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.14`.

#### Changes from opentelemetry-collector 0.130.14:
- [Fix] Ensure Coralogix exporter batcher from resource catalog pipeline uses the correct sizer.

#### Changes from opentelemetry-collector 0.130.13:
- [Fix] On-prem Kubernetes (`provider: on-prem` with a K8s distribution) now defaults `resourcedetection/resource_catalog` detectors to `[k8snode]` and `resourcedetection/env` detectors to `[env, k8snode, system]`, restoring the Coralogix Infra Catalog node/pod relationships that broke after the provider-aware change in v0.129.2 (CDS-2925).

### 0.0.19 / 2026-04-17

* [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.12`.

#### Changes from opentelemetry-collector 0.130.12:
- [Feat] Add optional `presets.coralogixExporter.keepalive` support so the chart only renders shared Coralogix exporter gRPC keepalive settings when explicitly configured.

#### Changes from opentelemetry-collector 0.130.11:
- [Fix] Use the dedicated supervised eBPF profiler image and managed collector executable when `presets.ebpfProfiler` and `presets.fleetManagement.supervisor` are both enabled.

### 0.0.18 / 2026-04-13

* [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.10`.

#### Changes from opentelemetry-collector 0.130.9:
- [Fix] Enable byte-sized Coralogix resource catalog exporter queue batching by default.
- [Fix] Bump queue size from 50mib to 200mib in batch queue for resource catalog exporter.

### 0.0.17 / 2026-04-10

* [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.8`.

#### Changes from opentelemetry-collector 0.130.8:
- [Fix] Add `IsMap()` guards to `transform/kube-events` processor to prevent `INVALID_ARGUMENT` when a Kubernetes event log body is a plain string (CDS-2869)

### 0.0.16 / 2026-04-09

* [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.7`.

#### Changes from opentelemetry-collector 0.130.7:
- [Feat] Add support for fallback configuration for the Supervisor.

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
