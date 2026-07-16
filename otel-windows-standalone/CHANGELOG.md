# Changelog

## otel-windows-standalone

### v0.0.46 / 2026-07-16

- [Chore] Version bump to keep standalone chart versions aligned (OBI support added to `otel-linux-standalone` v0.0.46).

### v0.0.45 / 2026-07-15

- [Chore] Bump chart dependency to opentelemetry-collector 0.135.1

#### Changes from opentelemetry-collector 0.135.1:
- [Feat] Upgrade Supervisor-based images to v0.11.0.

### v0.0.44 / 2026-07-08

- [Chore] Bump chart dependency to opentelemetry-collector 0.135.0

#### Changes from opentelemetry-collector 0.135.0:
- [Feat] Bump the OpenTelemetry Collector image to v0.155.0.
- [Feat] Upgrade Supervisor-based images to v0.10.0.
- [Fix] Restore legacy memory limiter metric names in the rendered collector pipeline for backward compatibility.

### v0.0.43 / 2026-07-07

- [Chore] Bump chart dependency to opentelemetry-collector 0.134.4

#### Changes from opentelemetry-collector 0.134.4:
- [Fix] Run Windows collectors with the logs collection preset as `NT AUTHORITY\SYSTEM` by default so they can read pod log files.

### v0.0.42 / 2026-07-01

- [Chore] Bump chart dependency to opentelemetry-collector 0.134.3

#### Changes from opentelemetry-collector 0.134.3:
- [Fix] The `profilesK8sAttributes` preset now is enabled by default.

### v0.0.41 / 2026-06-30

- [Chore] Bump chart dependency to opentelemetry-collector 0.134.2

#### Changes from opentelemetry-collector 0.134.2:
- [Feat] Add per-object startup delays for Kubernetes resource catalog periodic collection to spread initial pull requests.

### v0.0.40 / 2026-06-30

- [Chore] Bump chart dependency to opentelemetry-collector 0.134.1

#### Changes from opentelemetry-collector 0.134.1:
- [Fix] Use the ECS Coralogix distribution header for all ECS signals and centralize the header mapping in a shared template helper.

### v0.0.39 / 2026-06-23

- [Chore] Bump chart dependency to opentelemetry-collector 0.134.0

#### Changes from opentelemetry-collector 0.134.0:
- [Feat] Bump the OpenTelemetry Collector image to v0.154.0.
- [Feat] Upgrade Supervisor-based images to v0.9.0.

### v0.0.38 / 2026-06-16

- [Chore] Bump chart dependency to opentelemetry-collector 0.133.0

### v0.0.37 / 2026-06-08

- [Feat] Bump the OpenTelemetry Collector image to v0.152.1.

#### Changes from opentelemetry-collector 0.131.9:
- [Breaking] Fix `spanMetricsMulti` to apply the same extra dimensions (including `errorTracking` fallback from `presets.spanMetrics`) to all spanmetrics connectors, and skip auto-added status code dimensions when they are already listed in `extraDimensions`.
- [Breaking] Fix `spanmetrics/default` and routed `spanmetrics/<index>` connectors to match single `spanMetrics` compatibility defaults by setting `add_resource_attributes: true` and `histogram.unit: ms`, required for APM span metrics.

### v0.0.36 / 2026-05-27

- [Chore] Bump chart dependency to opentelemetry-collector 0.131.8

#### Changes from opentelemetry-collector 0.131.8:
- [Fix] Wrap the chart-managed `health_check` extension endpoint in IPv6 bracket notation when `networkMode: ipv6` is used, aligning it with the other IPv6-safe listener endpoints and allowing the collector to start and pass health probes on IPv6-only clusters.

### v0.0.35 / 2026-05-21

- [Chore] Bump chart dependency to opentelemetry-collector 0.131.7

#### Changes from opentelemetry-collector 0.131.7:
- [Feat] Add optional `transformStatements`, `spanNameReplacePattern`, `dbMetrics`, and `compactMetrics` to the `spanMetricsMulti` preset, matching the single `spanMetrics` preset capabilities. All are opt-in (`dbMetrics` / `compactMetrics` default to off; dimension helpers preserve prior `spanMetricsMulti` behavior unless explicitly configured).

### v0.0.34 / 2026-05-18

- [Chore] Bump chart dependency to opentelemetry-collector 0.131.6

#### Changes from opentelemetry-collector 0.131.6:
- [Fix] Rewrite chart-owned OTTL statements to use explicit context-prefixed paths, removing collector startup rewrite warnings across transform/filter presets.
- [Fix] Update example-only OTTL snippets to use explicit span attribute paths and regenerate rendered examples.

### v0.0.33 / 2026-05-18

- [Chore] Bump chart dependency to opentelemetry-collector 0.131.5

#### Changes from opentelemetry-collector 0.131.5:
- [Fix] Switch the `kubernetesAttributes` preset to `k8sattributes.extract.deployment_name_from_replicaset: true`, keeping `k8s.deployment.name` extraction while removing the extra `transform/k8s_attributes` workaround processor.

### v0.0.32 / 2026-05-14

- [Chore] Bump chart dependency to opentelemetry-collector 0.131.4

#### Changes from opentelemetry-collector 0.131.4:
- [Feat] Unify versioning of all Supervisor-based images and control it from `presets.fleetManagement.supervisor.imageVersion`. Top-level `image.tag` overrides has priority over this.
- [Feat] Upgrade image used by the Supervisor preset to the latest Coralogix Supervised Collector images, v0.6.0.
- [Feat] Add optional `presets.fleetManagement.supervisor.objstoreConfig` support to create and mount a Thanos Objstore ConfigMap, which will be used by the Supervisor.

### v0.0.31 / 2026-05-13

- [Chore] Bump chart dependency to opentelemetry-collector 0.131.3

#### Changes from opentelemetry-collector 0.131.3:
- [Breaking] Enable byte-sized batching for the Coralogix exporter sending queue by default. The collector can now consume more memory. See the [Coralogix exporter sending queue and batching](https://github.com/coralogix/telemetry-shippers/blob/master/otel-integration/k8s-helm/README.md#coralogix-exporter-sending-queue-and-batching) documentation for details.

### v0.0.30 / 2026-05-12

- [Chore] Bump chart dependency to opentelemetry-collector 0.131.2

#### Changes from opentelemetry-collector 0.131.2:
- [Feat] Enable `presets.coralogixExporter.keepalive` preset for Coralogix exporter by default.

#### Changes from opentelemetry-collector 0.131.1:
- [Feat] Support forwarding eBPF profiler profiles to a node-local agent with the `otlpExporter` preset, keeping Kubernetes attributes and profile service-name mapping on the standard agent collector.
- [Feat] Add the `x-coralogix-ingress: otlp/v1.10.0` header to Coralogix profile exports.
- [Fix] Match profile Kubernetes attributes by `container.id` before falling back to connection-based pod association.
- [Fix] Scope profile Kubernetes RBAC to the presets that configure `k8sattributes/profiles` and keep OTLP ports controlled by values.

#### Changes from opentelemetry-collector 0.131.0:
- [Feat] Bump OpenTelemetry Collector image to v0.151.0.

### v0.0.29 / 2026-04-30

- [Chore] Bump chart dependency to opentelemetry-collector 0.131.0

#### Changes from opentelemetry-collector 0.131.0:
- [Feat] Bump OpenTelemetry Collector image to v0.151.0.

### v0.0.28 / 2026-04-30

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.18

#### Changes from opentelemetry-collector 0.130.18:
- [Fix] Exclude `BOOKMARK` and `ERROR` watch event types from the `k8sobjects/resource_catalog` watch receivers used by the Kubernetes resource catalog presets, reducing non-actionable watch stream noise while preserving normal watch recovery behavior.

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

- [Chore] Align Windows chart version with linux-standalone (0.0.19)

### v0.0.11 / 2026-03-31

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.5

#### Changes from opentelemetry-collector 0.130.5:
- [Feat] For `distribution` `standalone` and `macos`, prepend `cx.application.name` and `cx.subsystem.name` to Coralogix exporter `application_name_attributes` and `subsystem_name_attributes` (before `service.namespace` / `service.name`) so presets such as `filelogMulti` and `prometheusMulti` drive Application/Subsystem when set.

### v0.0.10 / 2026-03-17

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.4

#### Changes from opentelemetry-collector 0.130.4:
- [Feat] Use Coralogix' custom Supervised Collector image when `presets.fleetManagement.supervisor` is enabled. For now this custom image includes fallback configuration support (local file and S3).

### v0.0.9 / 2026-03-16

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.3

#### Changes from opentelemetry-collector 0.130.3:
- [Fix] Preserve `telemetry.sdk.*` resource attributes on traces when `reduceResourceAttributes` is enabled in provider-based mode, while continuing to remove them for logs and metrics.

### v0.0.8 / 2026-03-13

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.2

#### Changes from opentelemetry-collector 0.130.2:
- [Fix] Pass `command.extraArgs` to the managed Collector through the supervisor `agent.args` configuration instead of appending them to the `opampsupervisor` container command.

### v0.0.7 / 2026-03-12

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.1

#### Changes from opentelemetry-collector 0.130.1:
- [Feat] Add optional `presets.ebpfProfiler.samplesPerSecond` support that maps to `receivers.profiling.samples_per_second` only when set.

### v0.0.6 / 2026-03-06

- [Chore] Bump chart dependency to opentelemetry-collector 0.130.0

#### Changes from opentelemetry-collector 0.130.0:
- [Feat] Bump OpenTelemetry Collector image to v0.147.0.

### v0.0.5 / 2026-02-26

- [Chore] Bump chart dependency to opentelemetry-collector 0.129.9

#### Changes from opentelemetry-collector 0.129.9:
- [Fix] Ensure `service.profilesSupport` is auto-injected for direct collector runs whenever `profilesCollection` or `ebpfProfiler` presets are enabled, including when fleet management is enabled without supervisor mode, while still avoiding duplicate gates when already provided in `command.extraArgs` or injected by supervisor.

### v0.0.4 / 2026-02-25

- [Chore] Bump chart dependency to opentelemetry-collector 0.129.8

#### Changes from opentelemetry-collector 0.129.8:
- [Fix] Ensure `service.profilesSupport` is automatically enabled for both `profilesCollection` and `ebpfProfiler` presets in both direct collector and supervisor modes, while avoiding duplicate feature-gate arguments when already set via `command.extraArgs`.

#### Changes from opentelemetry-collector 0.129.7:
- [Feat] Extend `ecsAttributesContainerLogs` with `profilesServiceName.enabled` to map profiles `service.name` from ECS resource attributes with fallback order `aws.ecs.task.definition.family` then `aws.ecs.container.name`, wiring the transform only into existing profiles pipelines.

### v0.0.3 / 2026-02-25

- [Chore] Bump chart dependency to opentelemetry-collector 0.129.6

#### Changes from opentelemetry-collector 0.129.6:
- [Fix] AWS resource detection for Deployments/StatefulSets. On EKS clusters where `HttpPutResponseHopLimit=1`, IMDS is not accessible from container pods, causing the EC2/EKS detectors to fail. Deployments/StatefulSets now use the `env` detector with `cloud.provider` and `cloud.platform` attributes injected via `OTEL_RESOURCE_ATTRIBUTES`.
- [Feat] Add top-level `provider` value (aws, gcp, azure, on-prem). When set, overrides inference from distribution. Enables self-managed K8s deployments with distribution="" and explicit provider. Self-managed on AWS uses EC2 detector only (no EKS) for DaemonSets.

#### Changes from opentelemetry-collector 0.129.5:
- [Fix] Use `aws.ecs.cluster.name` instead of `aws.ecs.cluster` for ECS distribution `application_name_attributes` to match the attribute name used by the `awsecscontainermetricsd` receiver.

### v0.0.2 / 2026-02-17

[Chore] Bump chart dependency to opentelemetry-collector 0.129.4

### v0.0.1 / 2026-02-09

- [Feat] Initial Windows standalone chart release
- [Feat] Windows Event Log receiver support (System, Application, Security channels)
- [Feat] IIS metrics receiver
- [Feat] IIS logs collection with W3C format parsing:
  - Header metadata parsing for dynamic field detection
  - CSV parsing with automatic header detection
  - Checkpoint storage enabled for resuming after collector restarts
  - Default path: `C:\inetpub\logs\LogFiles\W3SVC*\*.log`
  - IIS log fields mapped to OpenTelemetry semantic conventions:
    - `client.address`, `http.request.method`, `http.response.status_code`
    - `user_agent.original`, `url.path`, `url.query`
    - Custom attributes: `http.request.header.referer`, `http.server.request.duration_ms`
- [Feat] Host metrics with Windows-specific configurations:
  - Process metrics with Windows error suppression
  - Paging scraper enabled
  - Filesystem mount point exclusions for Windows
- [Feat] Host entity events for Windows Server
- [Feat] Fleet management (OpAMP) support
- [Feat] Resource detection and metadata collection
- [Feat] Collector metrics and telemetry endpoints (zpages, pprof)
