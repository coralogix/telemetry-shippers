# Changelog

## ecs-ec2-integration

### 0.0.19 / 2026-10-27

* [IMPROVEMENT] Updated the default supervised CDOT image to `cgx.jfrog.io/coralogix-docker-images/coralogix-otel-supervised-cdot:v0.18.0`, which bundles Supervisor 0.164.0. (PR pending)

### 0.0.18 / 2026-10-23

* [FIX] Updated the default supervised CDOT image to `cgx.jfrog.io/coralogix-docker-images/coralogix-otel-supervised-cdot:v0.17.1`, which bundles CDOT v0.5.18 (built with Go 1.26.10 and Alpine `ca-certificates` 20261020-r0) so the collector rejects the compromised eMudhra intermediates (CVE-2026-111943). ([#1076](https://github.com/coralogix/telemetry-shippers/pull/1076))

### 0.0.17 / 2026-10-22

* [IMPROVEMENT] Updated the default supervised CDOT image to `cgx.jfrog.io/coralogix-docker-images/coralogix-otel-supervised-cdot:v0.17.0`.
* [FIX] Removed the deprecated `reports_remote_config` setting for compatibility with the updated Supervisor.

### 0.0.16 / 2026-10-13

* [IMPROVEMENT] Updated the default supervised CDOT image to `coralogixrepo/coralogix-otel-supervised-cdot:v0.16.0`. (PR pending)

### 0.0.15 / 2026-09-23

* [IMPROVEMENT] Updated the default supervised CDOT image to `coralogixrepo/coralogix-otel-supervised-cdot:v0.15.0`. ([#1027](https://github.com/coralogix/telemetry-shippers/pull/1027))

### 0.0.14 / 2026-09-04

* [IMPROVEMENT] Updated the default supervised CDOT image to `coralogixrepo/coralogix-otel-supervised-cdot:v0.14.0`. ([#1013](https://github.com/coralogix/telemetry-shippers/pull/1013))

### 0.0.13 / 2026-08-26

* [IMPROVEMENT] Updated the default supervised CDOT image to `coralogixrepo/coralogix-otel-supervised-cdot:v0.13.0`. ([#1011](https://github.com/coralogix/telemetry-shippers/pull/1011))

### 0.0.12 / 2026-08-25
- [IMPROVEMENT] Use `30s` as config apply timeout for the Supervisor. ([#1008](https://github.com/coralogix/telemetry-shippers/pull/1008))

### 0.0.11 / 2026-08-11

* [IMPROVEMENT] Migrated the `coralogix_domain` default from the legacy `coralogix.com` to the regional `eu1.coralogix.com`. ([#990](https://github.com/coralogix/telemetry-shippers/pull/990))

### 0.0.10 / 2026-07-29

* [IMPROVEMENT] Updated the default supervised CDOT image to `coralogixrepo/coralogix-otel-supervised-cdot:v0.12.0`.

### 0.0.9 / 2026-07-15

* [IMPROVEMENT] Updated the default supervised CDOT image to `coralogixrepo/coralogix-otel-supervised-cdot:v0.11.0`.

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
