# Changelog

## otel-linux-standalone

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
