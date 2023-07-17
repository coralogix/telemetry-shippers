# Changelog

## OpenTelemtry-Infrastructure-Collector

### v0.1.3 / 2023-07-17

* [FEATURE] Add support for deploying `otel-infrastructure-collector` with OpenTelemetry Operator
* [FEATURE] Add MySQL preset for metrics and extra logs
* [CHORE] Update OpenTelemetry Collector to v0.77.0
* [CHORE] Use Coralogix fork for OpenTelemetry Collector Helm chart dependency

### v0.1.2 / 2023-05-08

* [FEATURE] Allow users to configure Coralogix domain instead of endpoints
* [CHORE] Update OpenTelemetry Collector to v0.76.1

### v0.1.1 / 2023-04-05

* [CHORE] Update OpenTelemetry Collector to v0.75.0

### v0.1.0 / 2023-03-20

* [FEATURE] Collecting Kubernetes events

### v0.0.4 / 2023-02-24

* [UPRADE] Upgrading chart version from 0.48.1 to 0.49.0

### v0.0.3 / 2023-02-14

* [UPRADE] Upgrading chart version from 0.40.7 to 0.48.1

### v0.0.2 / 2023-01-09

* [CHANGE] Change Prometheus job name for the collector itself
* [FIX] Change PodMonitor to ServiceMonitor since PodMonitor is not enabled in Deployment mode
