# Changelog

### v0.0.41 / 2026-07-16

- [Feat] Add opt-in OpenTelemetry eBPF Instrumentation (OBI) support. Set the Terraform `enable_obi` variable to run OBI (`ghcr.io/open-telemetry/opentelemetry-ebpf-instrumentation/ebpf-instrument:v0.10.0`) as a privileged sidecar in the collector task; it ships application spans & metrics to the node-local collector over OTLP. The OBI config is rendered with `make obi-config` into `obi/obi-config.yaml`. See `obi/README.md`.

### v0.0.40 / 2026-07-15

- [Change] Update Helm dependency `opentelemetry-agent` to chart version `0.135.1`.

#### Changes from opentelemetry-collector 0.135.1:
- [Feat] Upgrade Supervisor-based images to v0.11.0.

### v0.0.39 / 2026-07-08

- [Change] Update Helm dependency `opentelemetry-agent` to chart version `0.135.0`.

#### Changes from opentelemetry-collector 0.135.0:
- [Feat] Bump the OpenTelemetry Collector image to v0.155.0.
- [Feat] Upgrade Supervisor-based images to v0.10.0.
- [Fix] Restore legacy memory limiter metric names in the rendered collector pipeline for backward compatibility.

### v0.0.38 / 2026-07-07

- [Change] Update Helm dependency `opentelemetry-agent` to chart version `0.134.4`.

#### Changes from opentelemetry-collector 0.134.4:
- [Fix] Run Windows collectors with the logs collection preset as `NT AUTHORITY\SYSTEM` by default so they can read pod log files.

### v0.0.37 / 2026-07-01

- [Change] Update Helm dependency `opentelemetry-agent` to chart version `0.134.3`.

#### Changes from opentelemetry-collector 0.134.3:
- [Fix] The `profilesK8sAttributes` preset now is enabled by default.

### v0.0.36 / 2026-06-30

- [Change] Update Helm dependency `opentelemetry-agent` to chart version `0.134.2`.

#### Changes from opentelemetry-collector 0.134.2:
- [Feat] Add per-object startup delays for Kubernetes resource catalog periodic collection to spread initial pull requests.

### v0.0.35 / 2026-06-30

- [Change] Update Helm dependency `opentelemetry-agent` to chart version `0.134.1`.

#### Changes from opentelemetry-collector 0.134.1:
- [Fix] Use the ECS Coralogix distribution header for all ECS signals and centralize the header mapping in a shared template helper.

### v0.0.34 / 2026-06-23

- [Change] Update Helm dependency `opentelemetry-agent` to chart version `0.134.0`.

#### Changes from opentelemetry-collector 0.134.0:
- [Feat] Bump the OpenTelemetry Collector image to v0.154.0.
- [Feat] Upgrade Supervisor-based images to v0.9.0.

### v0.0.33 / 2026-06-16

- [Change] Update Helm dependency `opentelemetry-agent` to chart version `0.133.0`.

### v0.0.32 / 2026-06-08

- [Feat] Bump the OpenTelemetry Collector image to v0.152.1.

#### Changes from opentelemetry-collector 0.131.9:
- [Breaking] Fix `spanMetricsMulti` to apply the same extra dimensions (including `errorTracking` fallback from `presets.spanMetrics`) to all spanmetrics connectors, and skip auto-added status code dimensions when they are already listed in `extraDimensions`.
- [Breaking] Fix `spanmetrics/default` and routed `spanmetrics/<index>` connectors to match single `spanMetrics` compatibility defaults by setting `add_resource_attributes: true` and `histogram.unit: ms`, required for APM span metrics.

### v0.0.31 / 2026-05-27

- [Change] Update Helm dependency `opentelemetry-agent` to chart version `0.131.8`.

#### Changes from opentelemetry-collector 0.131.8:
- [Fix] Wrap the chart-managed `health_check` extension endpoint in IPv6 bracket notation when `networkMode: ipv6` is used, aligning it with the other IPv6-safe listener endpoints and allowing the collector to start and pass health probes on IPv6-only clusters.

### v0.0.30 / 2026-05-21

- [Change] Update Helm dependency `opentelemetry-agent` to chart version `0.131.7`.

#### Changes from opentelemetry-collector 0.131.7:
- [Feat] Add optional `transformStatements`, `spanNameReplacePattern`, `dbMetrics`, and `compactMetrics` to the `spanMetricsMulti` preset, matching the single `spanMetrics` preset capabilities. All are opt-in (`dbMetrics` / `compactMetrics` default to off; dimension helpers preserve prior `spanMetricsMulti` behavior unless explicitly configured).

### v0.0.29 / 2026-05-18

- [Change] Update Helm dependency `opentelemetry-agent` to chart version `0.131.6`.

#### Changes from opentelemetry-collector 0.131.6:
- [Fix] Rewrite chart-owned OTTL statements to use explicit context-prefixed paths, removing collector startup rewrite warnings across transform/filter presets.
- [Fix] Update example-only OTTL snippets to use explicit span attribute paths and regenerate rendered examples.

### v0.0.28 / 2026-05-18

- [Change] Update Helm dependency `opentelemetry-agent` to chart version `0.131.5`.

#### Changes from opentelemetry-collector 0.131.5:
- [Fix] Switch the `kubernetesAttributes` preset to `k8sattributes.extract.deployment_name_from_replicaset: true`, keeping `k8s.deployment.name` extraction while removing the extra `transform/k8s_attributes` workaround processor.

### v0.0.27 / 2026-05-14

- [Change] Update Helm dependency `opentelemetry-agent` to chart version `0.131.4`.

#### Changes from opentelemetry-collector 0.131.4:
- [Feat] Unify versioning of all Supervisor-based images and control it from `presets.fleetManagement.supervisor.imageVersion`. Top-level `image.tag` overrides has priority over this.
- [Feat] Upgrade image used by the Supervisor preset to the latest Coralogix Supervised Collector images, v0.6.0.
- [Feat] Add optional `presets.fleetManagement.supervisor.objstoreConfig` support to create and mount a Thanos Objstore ConfigMap, which will be used by the Supervisor.

### v0.0.26 / 2026-05-13

- [Change] Update Helm dependency `opentelemetry-agent` to chart version `0.131.3`.

#### Changes from opentelemetry-collector 0.131.3:
- [Breaking] Enable byte-sized batching for the Coralogix exporter sending queue by default. The collector can now consume more memory. See the [Coralogix exporter sending queue and batching](https://github.com/coralogix/telemetry-shippers/blob/master/otel-integration/k8s-helm/README.md#coralogix-exporter-sending-queue-and-batching) documentation for details.

### v0.0.25 / 2026-05-12

- [Change] Update Helm dependency `opentelemetry-agent` to chart version `0.131.2`.

#### Changes from opentelemetry-collector 0.131.2:
- [Feat] Enable `presets.coralogixExporter.keepalive` preset for Coralogix exporter by default.

#### Changes from opentelemetry-collector 0.131.1:
- [Feat] Support forwarding eBPF profiler profiles to a node-local agent with the `otlpExporter` preset, keeping Kubernetes attributes and profile service-name mapping on the standard agent collector.
- [Feat] Add the `x-coralogix-ingress: otlp/v1.10.0` header to Coralogix profile exports.
- [Fix] Match profile Kubernetes attributes by `container.id` before falling back to connection-based pod association.
- [Fix] Scope profile Kubernetes RBAC to the presets that configure `k8sattributes/profiles` and keep OTLP ports controlled by values.

#### Changes from opentelemetry-collector 0.131.0:
- [Feat] Bump OpenTelemetry Collector image to v0.151.0.

### v0.0.24 / 2026-05-07

* [CHANGE] Bump Coralogix OTEL collector image to `coralogixrepo/coralogix-otel-collector:v0.5.12` (aligned in Helm values, example manifest, Terraform `image_version` default, and Makefile `CDOT_IMAGE` default).

### v0.0.23 / 2026-04-30

- [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.18`.

#### Changes from opentelemetry-collector 0.130.18:
- [Fix] Exclude `BOOKMARK` and `ERROR` watch event types from the `k8sobjects/resource_catalog` watch receivers used by the Kubernetes resource catalog presets, reducing non-actionable watch stream noise while preserving normal watch recovery behavior.

### v0.0.22 / 2026-04-29

- [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.17`.

#### Changes from opentelemetry-collector 0.130.17:
- [Fix] Convert `supervisor.collector` wrapped collector logs into first-class log records when `presets.logsCollection.includeCollectorLogs` is enabled, preserving the nested collector severity, body, component attributes, and resource attributes instead of leaving them embedded in the outer `msg` string.

### v0.0.21 / 2026-04-27

- [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.16`.

#### Changes from opentelemetry-collector 0.130.16:
- [Feat] Use `connection` pod association for profiling k8sattributes processor

#### Changes from opentelemetry-collector 0.130.15:
- [Fix] Use `syslog_parser` for macOS system log parsing logic.

### v0.0.20 / 2026-04-22

- [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.14`.

#### Changes from opentelemetry-collector 0.130.14:
- [Fix] Ensure Coralogix exporter batcher from resource catalog pipeline uses the correct sizer.

#### Changes from opentelemetry-collector 0.130.13:
- [Fix] On-prem Kubernetes (`provider: on-prem` with a K8s distribution) now defaults `resourcedetection/resource_catalog` detectors to `[k8snode]` and `resourcedetection/env` detectors to `[env, k8snode, system]`, restoring the Coralogix Infra Catalog node/pod relationships that broke after the provider-aware change in v0.129.2 (CDS-2925).

### v0.0.19 / 2026-04-17

- [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.12`.

#### Changes from opentelemetry-collector 0.130.12:
- [Feat] Add optional `presets.coralogixExporter.keepalive` support so the chart only renders shared Coralogix exporter gRPC keepalive settings when explicitly configured.

#### Changes from opentelemetry-collector 0.130.11:
- [Fix] Use the dedicated supervised eBPF profiler image and managed collector executable when `presets.ebpfProfiler` and `presets.fleetManagement.supervisor` are both enabled.

### v0.0.18 / 2026-04-13

- [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.10`.

#### Changes from opentelemetry-collector 0.130.9:
- [Fix] Enable byte-sized Coralogix resource catalog exporter queue batching by default.
- [Fix] Bump queue size from 50mib to 200mib in batch queue for resource catalog exporter.

### v0.0.17 / 2026-04-10

- [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.8`.

#### Changes from opentelemetry-collector 0.130.8:
- [Fix] Add `IsMap()` guards to `transform/kube-events` processor to prevent `INVALID_ARGUMENT` when a Kubernetes event log body is a plain string (CDS-2869)

### v0.0.16 / 2026-04-09

- [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.7`.

#### Changes from opentelemetry-collector 0.130.7:
- [Feat] Add support for fallback configuration for the Supervisor.

### v0.0.15 / 2026-04-01

- [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.6`.

#### Changes from opentelemetry-collector 0.130.6:
- [Feat] Add target allocator `allocationFallbackStrategy`, `probeSelector`, and `probeNamespaceSelector` chart values for Prometheus CR rendering.

### v0.0.14 / 2026-03-31

- [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.5`.

#### Changes from opentelemetry-collector 0.130.5:
- [Feat] For `distribution` `standalone` and `macos`, prepend `cx.application.name` and `cx.subsystem.name` to Coralogix exporter `application_name_attributes` and `subsystem_name_attributes` (before `service.namespace` / `service.name`) so presets such as `filelogMulti` and `prometheusMulti` drive Application/Subsystem when set.

### v0.0.13 / 2026-03-20

- [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.4`.
- [CHANGE] Add `samplesPerSecond` to values.yaml with `20` by default

### v0.0.12 / 2026-03-19

- [CHANGE] Enable Coralogix exporter for `opentelemetry-ebpf-profiler`. This is used to generate another configuration for profiling in the form of a ConfigMap.

### v0.0.11 / 2026-03-12

- [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.130.1`.

### v0.0.10 / 2026-03-12

- [CHANGE] Bump Coralogix OTEL collector image to `coralogixrepo/coralogix-otel-collector:v0.5.9` (aligned in Helm values, example manifest, Terraform `image_version` default, and Makefile `CDOT_IMAGE` default).

### v0.0.9 / 2026-02-17

- [CHANGE] Bump Coralogix OTEL collector image to `coralogixrepo/coralogix-otel-collector:v0.5.8` (aligned in Helm values, example manifest, Terraform `image_version` default, and Makefile `CDOT_IMAGE` default).

### v0.0.8 / 2026-01-16

- [FEATURE] ECS attributes processor now supports spans and profiles.
- [FEATURE] Add eBPF profiler preset, disabled by default (`presets.ebpfProfiler.enabled=false`).

### v0.0.7 / 2026-01-06

- [CHANGE] Update Helm dependency `opentelemetry-agent` to chart version `0.128.1`.

### v0.0.6 / 2026-01-02

- [CHANGE] Bump Coralogix OTEL collector image to `coralogixrepo/coralogix-otel-collector:v0.5.7` (aligned in Helm values, example manifest, and Terraform `image_version` default).

### v0.0.5 / 2025-11-25

- [CHANGE] Bump Coralogix OTEL collector image to `coralogixrepo/coralogix-otel-collector:v0.5.6` (aligned in Helm values, example manifest, and Terraform `image_version` default).

### v0.0.4 / 2025-10-22

- [CHANGE] Bump Coralogix OTEL collector image to `coralogixrepo/coralogix-otel-collector:v0.5.2` (aligned in Helm values, example manifest, and Terraform `image_version` default).

## ecs-ec2-integration

### v0.0.3 / 2025-09-09

- [CHANGE] Bump Coralogix OTEL collector image to `coralogixrepo/coralogix-otel-collector:v0.5.1` (aligned in Helm values, example manifest, and Terraform `image_version` default).

### v0.0.2 / 2025-08-28

- [FEATURE] Enable resource reduction preset by default to reduce metrics/resource cardinality (`presets.reduceResourceAttributes.enabled=true`).
- [CHANGE] Switch default agent image to Coralogix distribution: `coralogixrepo/coralogix-otel-collector:v0.5.0`.
- [FEATURE] Allow users to enable multiline log recombination via `presets.ecsLogsCollection.multiline` (e.g., `lineStartPattern`, `omitPattern`).
