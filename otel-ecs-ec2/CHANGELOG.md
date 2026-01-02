# Changelog

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
