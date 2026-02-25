# Changelog

## otel-windows-standalone

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
