# Changelog

## otel-ecs-fargate

<!-- To add a new entry write: -->

<!-- ### version / full date -->

<!-- * [Update/Bug fix] message that describes the changes that you apply -->
### 0.0.3 / 2025-08-19

* [UPDATE] Added spanmetrics for ECS Fargate.
* [FIX] Fix metrics syntax.

### 0.0.2 / 2024-11-25

* [UPDATE] Added configs for ECS Fargate Resource Catalog support
* [UPDATE] Added hostmetrics receiver to collect limited host metrics from Fargate nodes

### 0.0.1 / 2024-10-21

* [DOCS] Update Documentation with option for Advanced Parameter Store (4kb -> 8kb config size)

### 0.0.1 / 2024-10-15

* [DOCS] Update Documentation with optional Secrets Manager for Private Key

### 0.0.1 / 2024-09-11

### 🛑 Breaking changes 🛑
* [UPDATE] Update ecs-fargate integration to OTEL only (remove fluentbit logrouter)
