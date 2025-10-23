# Changelog

## ecs-ec2-integration

### 0.0.2 / 2025-10-22

* [IMPROVEMENT] Extracted ECS cluster and EC2 capacity resources into a reusable local Terraform module so the root configuration can either create or reference an existing cluster without changing other behaviors. ([#690](https://github.com/coralogix/telemetry-shippers/pull/690))

### 0.0.1 / 2025-09-24

* [FEATURE] Provide Terraform integration to deploy `supervisor` image in ECS.
