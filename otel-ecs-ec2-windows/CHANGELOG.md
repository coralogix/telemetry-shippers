# Changelog

## ecs-ec2-windows-integration

### 0.0.1 / 2026-03-17

* Initial release: ECS EC2 Windows OpenTelemetry Integration.
* Chart `ecs-ec2-windows-integration` with Windows-aware config (otel-config.yaml as source of truth).
* Coralogix OTEL collector image `coralogixrepo/coralogix-otel-collector:v0.5.7`; Helm dependency `opentelemetry-agent` 0.128.11.
* Windows-specific defaults: eBPF profiler disabled; ECS container metrics daemon in sidecar mode; resource detection (env + ec2) without system detector; Opamp and ecsattributes/container-logs disabled for Windows compatibility.
