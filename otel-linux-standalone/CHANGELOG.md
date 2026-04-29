# Changelog

## otel-linux-standalone

### v0.0.27 / 2026-04-29

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.17

#### Changes from opentelemetry-collector 0.130.17:
- [Fix] Convert `supervisor.collector` wrapped collector logs into first-class log records when `presets.logsCollection.includeCollectorLogs` is enabled, preserving the nested collector severity, body, component attributes, and resource attributes instead of leaving them embedded in the outer `msg` string.

### v0.0.26 / 2026-04-27

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.16

#### Changes from opentelemetry-collector 0.130.16:
- [Feat] Use `connection` pod association for profiling k8sattributes processor

#### Changes from opentelemetry-collector 0.130.15:
- [Fix] Use `syslog_parser` for macOS system log parsing logic.

### v0.0.25 / 2026-04-22

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.14

#### Changes from opentelemetry-collector 0.130.14:
- [Fix] Ensure Coralogix exporter batcher from resource catalog pipeline uses the correct sizer.

#### Changes from opentelemetry-collector 0.130.13:
- [Fix] On-prem Kubernetes (`provider: on-prem` with a K8s distribution) now defaults `resourcedetection/resource_catalog` detectors to `[k8snode]` and `resourcedetection/env` detectors to `[env, k8snode, system]`, restoring the Coralogix Infra Catalog node/pod relationships that broke after the provider-aware change in v0.129.2 (CDS-2925).

### v0.0.24 / 2026-04-17

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.12

#### Changes from opentelemetry-collector 0.130.12:
- [Feat] Add optional `presets.coralogixExporter.keepalive` support so the chart only renders shared Coralogix exporter gRPC keepalive settings when explicitly configured.

#### Changes from opentelemetry-collector 0.130.11:
- [Fix] Use the dedicated supervised eBPF profiler image and managed collector executable when `presets.ebpfProfiler` and `presets.fleetManagement.supervisor` are both enabled.

### v0.0.23 / 2026-04-13

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.10

#### Changes from opentelemetry-collector 0.130.9:
- [Fix] Enable byte-sized Coralogix resource catalog exporter queue batching by default.
- [Fix] Bump queue size from 50mib to 200mib in batch queue for resource catalog exporter.

### v0.0.22 / 2026-04-10

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.8

#### Changes from opentelemetry-collector 0.130.8:
- [Fix] Add `IsMap()` guards to `transform/kube-events` processor to prevent `INVALID_ARGUMENT` when a Kubernetes event log body is a plain string (CDS-2869)

### v0.0.21 / 2026-04-09

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.7

#### Changes from opentelemetry-collector 0.130.7:
- [Feat] Add support for fallback configuration for the Supervisor.

### v0.0.20 / 2026-04-01

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.6

#### Changes from opentelemetry-collector 0.130.6:
- [Feat] Add target allocator `allocationFallbackStrategy`, `probeSelector`, and `probeNamespaceSelector` chart values for Prometheus CR rendering.

### v0.0.19 / 2026-03-31

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.5

#### Changes from opentelemetry-collector 0.130.5:
- [Feat] For `distribution` `standalone` and `macos`, prepend `cx.application.name` and `cx.subsystem.name` to Coralogix exporter `application_name_attributes` and `subsystem_name_attributes` (before `service.namespace` / `service.name`) so presets such as `filelogMulti` and `prometheusMulti` drive Application/Subsystem when set.

### v0.0.18 / 2026-03-17

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.4

#### Changes from opentelemetry-collector 0.130.4:
- [Feat] Use Coralogix' custom Supervised Collector image when `presets.fleetManagement.supervisor` is enabled. For now this custom image includes fallback configuration support (local file and S3).

### v0.0.17 / 2026-03-16

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.3

#### Changes from opentelemetry-collector 0.130.3:
- [Fix] Preserve `telemetry.sdk.*` resource attributes on traces when `reduceResourceAttributes` is enabled in provider-based mode, while continuing to remove them for logs and metrics.

### v0.0.16 / 2026-03-13

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.2

#### Changes from opentelemetry-collector 0.130.2:
- [Fix] Pass `command.extraArgs` to the managed Collector through the supervisor `agent.args` configuration instead of appending them to the `opampsupervisor` container command.

### v0.0.15 / 2026-03-12

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.1

#### Changes from opentelemetry-collector 0.130.1:
- [Feat] Add optional `presets.ebpfProfiler.samplesPerSecond` support that maps to `receivers.profiling.samples_per_second` only when set.

### v0.0.14 / 2026-03-06

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.0

#### Changes from opentelemetry-collector 0.130.0:
- [Feat] Bump OpenTelemetry Collector image to v0.147.0.

### v0.0.13 / 2026-02-26

- [Chore] Bump chart dependency to opentelemetry-collector 0.129.9

#### Changes from opentelemetry-collector 0.129.9:
- [Fix] Ensure `service.profilesSupport` is auto-injected for direct collector runs whenever `profilesCollection` or `ebpfProfiler` presets are enabled, including when fleet management is enabled without supervisor mode, while still avoiding duplicate gates when already provided in `command.extraArgs` or injected by supervisor.

### v0.0.12 / 2026-02-25

- [Chore] Bump chart dependency to opentelemetry-collector 0.129.8

#### Changes from opentelemetry-collector 0.129.8:
- [Fix] Ensure `service.profilesSupport` is automatically enabled for both `profilesCollection` and `ebpfProfiler` presets in both direct collector and supervisor modes, while avoiding duplicate feature-gate arguments when already set via `command.extraArgs`.

#### Changes from opentelemetry-collector 0.129.7:
- [Feat] Extend `ecsAttributesContainerLogs` with `profilesServiceName.enabled` to map profiles `service.name` from ECS resource attributes with fallback order `aws.ecs.task.definition.family` then `aws.ecs.container.name`, wiring the transform only into existing profiles pipelines.

### v0.0.11 / 2026-02-25

- [Chore] Bump chart dependency to opentelemetry-collector 0.129.6

#### Changes from opentelemetry-collector 0.129.6:
- [Fix] AWS resource detection for Deployments/StatefulSets. On EKS clusters where `HttpPutResponseHopLimit=1`, IMDS is not accessible from container pods, causing the EC2/EKS detectors to fail. Deployments/StatefulSets now use the `env` detector with `cloud.provider` and `cloud.platform` attributes injected via `OTEL_RESOURCE_ATTRIBUTES`.
- [Feat] Add top-level `provider` value (aws, gcp, azure, on-prem). When set, overrides inference from distribution. Enables self-managed K8s deployments with distribution="" and explicit provider. Self-managed on AWS uses EC2 detector only (no EKS) for DaemonSets.

#### Changes from opentelemetry-collector 0.129.5:
- [Fix] Use `aws.ecs.cluster.name` instead of `aws.ecs.cluster` for ECS distribution `application_name_attributes` to match the attribute name used by the `awsecscontainermetricsd` receiver.

### v0.0.10 / 2026-02-16

- [Chore] Bump chart dependency to opentelemetry-collector 0.129.5

#### Changes from opentelemetry-collector 0.129.5:

#### v0.129.5
- [Fix] Use `aws.ecs.cluster.name` instead of `aws.ecs.cluster` for ECS distribution `application_name_attributes` to match the attribute name used by the `awsecscontainermetricsd` receiver.

### v0.0.9 / 2026-02-13

- [Chore] Bump chart dependency to opentelemetry-collector 0.129.4

#### Changes from opentelemetry-collector 0.129.4:
- [Fix] Increase the `presets.loadBalancing.k8s.timeout` default to `1m` so Kubernetes resolver users get a longer resolver timeout by default.

### v0.0.8 / 2026-02-10

- [Chore] Bump chart dependency to opentelemetry-collector 0.129.2

### v0.0.7 / 2026-02-08

- [Fix] Remove debug exporter from pipeline configs

### v0.0.6 / 2026-02-03

- [Chore] Bump chart dependency to opentelemetry-collector 0.128.18

### v0.0.5 / 2026-01-27

- [Chore] Bump chart dependency to opentelemetry-collector 0.128.15

### v0.0.4 / 2026-01-15

- [Chore] Bump chart dependency to opentelemetry-collector 0.128.8
- [Feat] Add systemdReceiver
