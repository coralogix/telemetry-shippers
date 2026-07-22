# Changelog

## otel-ecs-fargate

<!-- To add a new entry write: -->

<!-- ### version / full date -->

<!-- * [Update/Bug fix] message that describes the changes that you apply -->

### 1.1.1 / 2026-07-21

* [Bug fix] Map the legacy `http.status_code` attribute to `http.response.status_code` in the `semconv` transform so span metrics carry the status code for spans using the old HTTP semantic convention.

### 1.1.0 / 2026-06-30

* [UPDATE] Use `otlp` v1.10.0 for profiles ingestion

### 1.0.0 / 2026-03-11

* [UPDATE] Changed from Parameter Store to S3 for configuration
* [UPDATE] Updated example configuration to be inline with ECS EC2 configuration

### 0.0.4 / 2025-10-09

* [UPDATE] Added DB spanmetrics for ECS Fargate.

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
