# Changelog

## ecs-ec2-windows-integration

### 0.0.2 / 2026-04-16

* Recover `ecsattributesprocessor`, falling back to ECS Task Metadata

### 0.0.1 / 2026-03-17

* Initial release: ECS EC2 Windows OpenTelemetry Integration.
* Chart `ecs-ec2-windows-integration` with Windows-aware config (otel-config.yaml as source of truth).
* Coralogix OTEL collector image `coralogixrepo/coralogix-otel-collector:v0.5.7`; Helm dependency `opentelemetry-agent` 0.128.11.
* Windows-specific defaults: eBPF profiler disabled; ECS container metrics daemon in sidecar mode; resource detection (env + ec2) without system detector; Opamp disabled for Windows compatibility; ecsattributes/container-logs uses `container.id` sources only (no `sidecar` key in current collector config schema).
