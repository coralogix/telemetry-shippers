# Changelog

## ecs-ec2-integration

### 0.0.8 / 2026-07-07

* [IMPROVEMENT] Updated the default supervised CDOT image to `coralogixrepo/coralogix-otel-supervised-cdot:v0.10.0`.

### 0.0.7 / 2026-06-22

* [IMPROVEMENT] Updated the default supervised CDOT image tag to `v0.9.0`.

### 0.0.6 / 2026-06-16

* [IMPROVEMENT] Updated the default supervised CDOT image tag to `v0.8.0`.

### 0.0.5 / 2026-06-08

* [IMPROVEMENT] Updated the default supervised CDOT image tag to `v0.7.0`.

### 0.0.4 / 2026-02-05

* [IMPROVEMENT] Added supervisor image using cdot 0.5.7.

### 0.0.3 / 2025-11-21

* [IMPROVEMENT] Updated the default supervised collector image tag to `0.140.1` to align with the latest collector and supervisor release.

### 0.0.2 / 2025-10-22

* [IMPROVEMENT] Extracted ECS cluster and EC2 capacity resources into a reusable local Terraform module so the root configuration can either create or reference an existing cluster without changing other behaviors. ([#690](https://github.com/coralogix/telemetry-shippers/pull/690))

### 0.0.1 / 2025-09-24

* [FEATURE] Provide Terraform integration to deploy `supervisor` image in ECS.
