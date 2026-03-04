# Changelog

## otel-linux-standalone

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
