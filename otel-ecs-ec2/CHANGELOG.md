# Changelog

## ecs-ec2-integration

### 0.0.2 / 2025-08-28

* [FEATURE] Enable resource reduction preset by default to reduce metrics/resource cardinality (`presets.reduceResourceAttributes.enabled=true`).
* [CHANGE] Switch default agent image to Coralogix distribution: `coralogixrepo/coralogix-otel-collector:v0.5.0`.
* [FEATURE] Allow users to enable multiline log recombination via `presets.ecsLogsCollection.multiline` (e.g., `lineStartPattern`, `omitPattern`).
