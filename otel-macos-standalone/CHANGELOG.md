# Changelog

## otel-macos-standalone

### v0.0.11 / 2026-02-25

- [Chore] Bump chart dependency to opentelemetry-collector 0.129.7

#### Changes from opentelemetry-collector 0.129.7:
- [Feat] Extend `ecsAttributesContainerLogs` with `profilesServiceName.enabled` to map profiles `service.name` from ECS resource attributes with fallback order `aws.ecs.task.definition.family` then `aws.ecs.container.name`, wiring the transform only into existing profiles pipelines.

### v0.0.10 / 2026-02-25

- [Chore] Bump chart dependency to opentelemetry-collector 0.129.6

#### Changes from opentelemetry-collector 0.129.6:
- [Fix] AWS resource detection for Deployments/StatefulSets. On EKS clusters where `HttpPutResponseHopLimit=1`, IMDS is not accessible from container pods, causing the EC2/EKS detectors to fail. Deployments/StatefulSets now use the `env` detector with `cloud.provider` and `cloud.platform` attributes injected via `OTEL_RESOURCE_ATTRIBUTES`.
- [Feat] Add top-level `provider` value (aws, gcp, azure, on-prem). When set, overrides inference from distribution. Enables self-managed K8s deployments with distribution="" and explicit provider. Self-managed on AWS uses EC2 detector only (no EKS) for DaemonSets.

#### Changes from opentelemetry-collector 0.129.5:
- [Fix] Use `aws.ecs.cluster.name` instead of `aws.ecs.cluster` for ECS distribution `application_name_attributes` to match the attribute name used by the `awsecscontainermetricsd` receiver.

### v0.0.9 / 2026-02-16

- [Chore] Bump chart dependency to opentelemetry-collector 0.129.5

#### Changes from opentelemetry-collector 0.129.5:

#### v0.129.5
- [Fix] Use `aws.ecs.cluster.name` instead of `aws.ecs.cluster` for ECS distribution `application_name_attributes` to match the attribute name used by the `awsecscontainermetricsd` receiver.

### v0.0.8 / 2026-02-13

- [Chore] Bump chart dependency to opentelemetry-collector 0.129.4

#### Changes from opentelemetry-collector 0.129.4:
- [Fix] Increase the `presets.loadBalancing.k8s.timeout` default to `1m` so Kubernetes resolver users get a longer resolver timeout by default.

### v0.0.7 / 2026-02-10

- [Chore] Bump chart dependency to opentelemetry-collector 0.129.2

### v0.0.6 / 2026-02-08

- [Fix] Remove debug exporter from pipeline configs
- [Feat] Add prometheus receiver and telemetry metrics host overrides with OTEL_LISTEN_INTERFACE

### v0.0.5 / 2026-02-03

- [Chore] Bump chart dependency to opentelemetry-collector 0.128.18

### v0.0.4 / 2026-01-15

- [Chore] Bump chart dependency to opentelemetry-collector 0.128.8

### v0.0.3 / 2026-01-06

- [Chore] Bump chart dependency to opentelemetry-collector 0.128.1

### v0.0.2 / 2025-12-25

- [Faet] Bump chart version to 0.127.7

### v0.0.1 / 2025-12-08
- [Feat] Add macOS standalone OpenTelemetry Collector chart with Coralogix exporter, host metrics, OTLP receiver, and macOS system log parsing defaults.
- [Feat] Provide macOS launchd installer/uninstaller scripts that download otelcol-contrib and inject `CORALOGIX_PRIVATE_KEY` at runtime.
