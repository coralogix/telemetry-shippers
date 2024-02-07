# Changelog

## OpenTelemtry-Integration

### v0.0.53 / 2024-02-07

- [FIX] Fix warning about overwrite in traces pipeline in cluster collector sub-chart.

### v0.0.52 / 2024-02-05

- [FEAT] Optionally allow users to use tail sampling for traces.

### v0.0.51 / 2024-02-05

- [FIX] Fix Target allocator endpoint slices permission issue.

### v0.0.50 / 2024-01-18

- [FEAT] Add global metric collection interval. This **changes** the default value of collection interval for all receivers to `30s` by default.
- [FIX] Suppress generation of `service.name` from collector telemetry.

### v0.0.49 / 2024-01-18

- [CHORE] Update Windows collector image to `v0.92.0`.
- [CHORE] Sync changes from main values file with Windows agent values file.

### v0.0.48 / 2024-01-17

- [FEATURE] Add support for specifying histogram buckets for span metrics preset.
- [CHORE] Update collector to `v0.92.0`.

### v0.0.47 / 2024-01-16

- [FIX] Suppress generation of `service.instance.id` from collector telemetry.

### v0.0.46 / 2024-01-11

- [CHORE] Update Windows collector image to `v0.91.0`
- [FIX] Disable unsued tracing pipeline in cluster collector

### v0.0.45 / 2024-01-05

- [FIX] Fix target allocator resources not being applied previously.
- [FIX] Bump target allocator to fix issues with allocator not allocating targets on cluster scaling.

### v0.0.44 / 2023-12-13

- [CHORE] Update collector to `v0.91.0`.
- [FEATURE] Remove memoryballast and enable GOMEMLIMIT instead. This should significantly reduce memory footprint. See https://github.com/open-telemetry/opentelemetry-helm-charts/issues/891.

### v0.0.43 / 2023-12-12

- [FIX] Use correct labels for target allocator components.
- [CHORE] Specify replica parameter for target allocator.

### v0.0.42 / 2023-12-11

- [CHORE] Update collector to `v0.90.1`.
- [FEATURE] Add feature to scrape Prometheus CR targets with target allocator.

### v0.0.41 / 2023-12-06

- [FIX] Enable Agent Service for GKE Autopilot clusters.

### v0.0.40 / 2023-12-01

- [FEATURE] Add support for GKE Autopilot clusters.

### v0.0.39 / 2023-11-30

- [FIX] Fix cluster collector k8sattributes should not filter on node level.

### v0.0.38 / 2023-11-28

- [FIX] Fix k8s.deployment.name transformation, in case the attribute already exists.
- [FIX] Kubelet Stats use Node IP instead of Node name.

### v0.0.37 / 2023-11-27
* [:warning: BREAKING CHANGE] [FEATURE] Add support for span metrics preset. This replaces the deprecated `spanmetricsprocessor`
  with `spanmetricsconnector`. The new connector is disabled by default, as opposed the replaces processor.
  To enable it, set `presets.spanMetrics.enabled` to `true`.

### v0.0.36 / 2023-11-15
* [FIX] Change statsd receiver port to 8125 instead of 8127

### v0.0.35 / 2023-11-14
* [FEATURE] Adds statsd receiver to listen for metrics on 8125 port.

### v0.0.34 / 2023-11-13
* [FIX] Remove Kube-State-Metrics receive_creator, which generated unnecessary configuration.

### v0.0.33 / 2023-11-08
* [FIX] Remove Kube-State-Metrics, as K8s Cluster Receiver provides all the needed metrics.

### v0.0.32 / 2023-11-03
* [FIX] Ensure correct order of processors for k8s deployment attributes.

### v0.0.31 / 2023-11-03
* [FIX] Fix scraping Kube State Metrics
* [CHORE] Update Collector to 0.88.0 (v0.76.0)
* [FIX] Fix consistent k8s.deployment.name attribute

### v0.0.30 / 2023-10-31
* [FEATURE] Add support for defining priority class

### v0.0.29 / 2023-10-31
* [FIX] Fix support for openshift

### v0.0.28 / 2023-10-30
* [CHORE] Update Collector to 0.87.0 (v0.75.0)

### v0.0.27 / 2023-10-30
* [CHORE] Update Collector to 0.86.0 (v0.74.0)

### v0.0.26 / 2023-10-30
* [CHORE] Upgrading upstream chart. (v0.73.7)

### v0.0.25 / 2023-10-26
* [CHORE] Remove unnecessary cloud resource detector configuration.

### v0.0.24 / 2023-10-26
* [FIX] service::pipelines::logs: references exporter "k8sattributes" which is not configured

### v0.0.23 / 2023-10-26
* [FEATURE] Add k8sattributes and resourcedetecion processor for logs and traces in agent.

### v0.0.22 / 2023-10-24
* [FEATURE] Add support for Windows node agent

### v0.0.21 / 2023-10-11

* [FIX] Fix missing `hostNetwork` field for CRD-based deployment
* [CHORE] Simplfy CRD override - put into a separate file

### v0.0.20 / 2023-10-06

* [CHORE] Bump Collector to 0.85.0

### v0.0.19 / 2023-10-05

* [CHORE] Bump Collector to 0.84.0

### v0.0.18 / 2023-10-04

* [FIX] hostmetrics don't scrape /run/containerd/runc/* for filesystem metrics

### v0.0.17 / 2023-09-29

* [FIX] Remove redundant `-agent` from `fullnameOverride` field of `values.yaml`

### v0.0.16 / 2023-09-28

* [FIX] Remove `k8s.pod.name`,`k8s.job.name` and `k8s.node.name` from subsystem attribute list

### v0.0.15 / 2023-09-15

* [FIX] Set k8s.cluster.name to all signals.
* [CHORE] Upgrading upstream chart. (v0.71.2)

### v0.0.14 / 2023-09-04

* [CHORE] Upgrading upstream chart. (v0.71.1)

### v0.0.13 / 2023-08-22

* [FIX] Change `k8s.container.name` to `k8s.pod.name` attribute

### v0.0.12 / 2023-08-21

* [FEATURE] Support host.id from system resource detector.

### v0.0.11 / 2023-08-18

* [CHORE] Upgrading upstream chart. (v0.71.0).
* [CHORE] Update Opentelemetry Collector 0.81.0 -> 0.83.0.
* [CHORE] Merges changes from upstream.

### v0.0.10 / 2023-08-14

* [FEATURE] Add CRD generation feature
* [FEATURE] Add MySQL preset

### v0.0.9 / 2023-08-11

* [CHORE] Upgrading upstream chart. (v0.70.1)

### v0.0.8 / 2023-08-11

* [CHORE] Upgrading upstream chart. (v0.69.0)

### v0.0.7 / 2023-08-11

* [FEATURE] Align `cx.otel_integration.name` with the new internal requirements

### v0.0.6 / 2023-08-08

* [CHORE] Bump Coralogix OpenTelemetry chart to `0.68.0`
* [FEATURE] Make `k8s.node.name` label the target node for Kubernetes node info metric

### v0.0.5 / 2023-08-04

* [FIX] Fix `kube-event` transfrom processor configuration to correctly filter log body keys

### v0.0.4 / 2023-08-03

* [FEATURE] Add cluster metrics related to allocatable resources (CPU, memory)
* [CHORE] Remove unused `cx.otel_integration.version` attribute
* [CHORE] Remove unused `enabled` parameter on `kube-state-metrics` config

### v0.0.3 / 2023-08-02

* [CHORE] Bump Coralogix OpenTelemetry chart to `0.67.0`

### v0.0.2 / 2023-08-02

* [FEATURE] Add `k8s.node.name` resource attribute to cluster collector
* [FEATURE] Override detection for cloud provider detectors
* [BUG] Fix ports configuration

### v0.0.1 / 2023-07-21

* [FEATURE] Add new chart
