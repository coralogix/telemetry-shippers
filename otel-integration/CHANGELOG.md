# Changelog

## OpenTelemtry-Integration

### v0.0.140 / 2025-02-04

- [Fix] Prioritize memory limiter processor in all pipelines.

### v0.0.139 / 2025-02-03

- [Feat] Add a startup probe to the cluster collector.

### v0.0.138 / 2025-01-31

- [Feat] Add extraConfig to allow adding extra processors, receivers, exporters, and connectors to the collector.

### v0.0.137 / 2025-01-29

- [Feat] Enable hostEntity and kubernetesResource preset

### v0.0.136 / 2025-01-14

- [Fix] Add missing `source_identifier` to `presets.logsCollection.multilineConfigs`

### v0.0.135 / 2025-01-09

- [Feat] Bump Windows 2019 image to the latest LTSC image for such version
- [:warning: Change][Feat] Bump Collector version in Windows nodes to `0.116.0`
  If you're using the Windows tailsampling values, please see the note about change in behavior in [`the 0.89.0 to 0.90.0 section of UPGRADING.md`](./UPGRADING.md#0089-to-0090).
  The default Windows values is NOT affected..
- [Fix] Update some missing/divergent configuration in the Windows tailsampling values file

### v0.0.134 / 2025-01-09

- [Feat] Upgrade OpenTelemetry Collector to `0.117.0`

### v0.0.133 / 2025-01-09

- [Feat] use v1 entity endpoint for resource catalog

### v0.0.132 / 2025-01-08

- [Feat] add entity interval for objects coming from kubernetesResources preset.

### v0.0.131 / 2025-01-07

- [Feat] Upgrade OpenTelemetry Collector to `0.116.0`

### v0.0.130 / 2025-01-02

- [Fix] Rollback the default host of the metrics telemetry service to the pod's IP.
  If you are using the OpenTelemetry Operator and the Collector CRD, please update
  the Operator to version `0.116.0` or later

### v0.0.129 / 2024-12-31

- [Feat] Add k8s job name plus other pod association rules for the k8s metadata processor

### v0.0.128 / 2024-12-23

- [Feat] add k8s ipv6 only support

### v0.0.127 / 2024-12-20

- [Fix] Make the receiver Collector report as agent type `receiver`
- [Feat] Add fleet management preset configuration to the Windows values files

### v0.0.126 / 2024-12-19

- [Feat] add service.version to spanMetrics and dbMetrics

### v0.0.125 / 2024-12-12

- [Feat] allow deploying of coralogix-ebpf-agent with existing collector

### v0.0.124 / 2024-12-10

- [Feat] remove hostmetrics from the pipeline in default values.yaml, as it is added automatically by the preset

### v0.0.123 / 2024-12-09

- [Fix] remove component.UseLocalHostAsDefaultHost feature gate from windows installations

### v0.0.122 / 2024-12-06

- [Feat] E2E Testing: Added deploying via kubeconfig to spin up telemetrygen. Traces are now tested.
- [Feat] E2E Testing: Added scopes scanning to prevent unwanted otel config changes (e.g. spanmetrics)

### v0.0.121 / 2024-12-05

- [Feat] Bump coralogix-ebpf-agent version to `0.1.5`

### v0.0.120 / 2024-12-05

- [Feat] Bump collector version to `0.115.0`
- [Feat] Bump Target Allocator version to `0.114.0`

### v0.0.119 / 2024-12-05

- [Fix] Target Allocator configmap name conflicting with collector configmap.

### v0.0.118 / 2024-12-04

- [Feat] Add ebpf tracing agent subchart.

### v0.0.117 / 2024-12-03

- [Feat] Adding new configs to the Target Allocator.

### v0.0.116 / 2024-11-29

- [Fix] Change the default value of the metrics telemetry service address to `0.0.0.0:8888`.

### v0.0.115 / 2024-11-28

- [Fix] Make the metrics telemetry service listen on `0.0.0.0` instead of using shell var expansion to resolve the pod IP.

### v0.0.114 / 2024-11-27

- [Feat] Add the `errorTracking` preset. It's enabled by default when `spanMetrics` is also enabled.

### v0.0.113 / 2024-11-21

- [Fix] Setting max_batch_size for logsCollection preset now works on all recombine operators.

### v0.0.112 / 2024-11-06

- [Feat] add ec2/azure resource detecion for kubernetes resource collection.
- [Feat] Add support for scraping cadvisor metrics per node on daemonset

### v0.0.111 / 2024-11-05

- [Feat] add aks/eks/gcp resource detecion for kubernetes resource collection.

### v0.0.110 / 2024-11-04

- [Feat] logsCollection preset allow changing max_batch_size

### v0.0.109 / 2024-10-23

- [Feat] E2E Testing: Populated hostmetrics maps and enable process metrics

### v0.0.108 / 2024-10-22

- [Feat] add dbMetrics option to spanMetrics preset, which is enabled when spanMetrics enabled. You can disable it using spanMetrics.dbMetrics.enabled=false.

### v0.0.107 / 2024-10-08

- [Feat] Upgrading base otel chart to 0.95.1

### v0.0.106 / 2024-10-08

- [Feat] Bump collector version to `0.111.0`

### v0.0.105 / 2024-09-30

- [Breaking] Change spanmetrics to disabled by default, which was enabled by mistake in v0.0.102

### v0.0.104 / 2024-09-26

- [Feat] Bump collector version to `0.110.0`

### v0.0.103 / 2024-09-23

- [Fix] agent_description.non_identifying_attributes expected a map, got 'slice'
- [Fix] Change opamp poll interval to 2 minutes

### v0.0.102 / 2024-09-10

- [Feat] Bump collector version to `0.109.0`
- [Feat] Allow TA to pass static config

### v0.0.101 / 2024-09-05

- [Fix] Fix Tail sampling gateway / receiver k8s attribute collection

### v0.0.100 / 2024-08-30

- [Feat] Bump collector version to `0.108.0`

### v0.0.99 / 2024-08-29

- [Fix] Change central-agent-values.yaml log level to warn
- [Fix] Turn off k8sattributes preset for central collector cluster

### v0.0.98 / 2024-08-29

- [Feat] Add a way to deploy central collector cluster for tail sampling

### v0.0.97 / 2024-08-19

- [Fix] ignore process name not found errors for hostmetrics process preset

### v0.0.96 / 2024-08-16

- [:warning: CHANGE] [FEAT] Bump collector version to `0.107.0`. Old way of providing environment variables in the collector configuration has been removed. If you are providing your own environment variables that are being expanded in the collector configuration, be sure to use the recommended syntax (for example with `env` prefix - `${env:ENV_VAR}` or `${ENV_VAR}` instead of just `$ENV_VAR`). For more information see previous [upgrading guide](https://github.com/coralogix/telemetry-shippers/blob/master/otel-integration/UPGRADING.md#0084-to-0085).
- [FIX] Restore previously mistakenly changed default log level to `warn`.

### v0.0.95 / 2024-08-14

- [Feat] add k8s.cluster.name to entity events

### v0.0.94 / 2024-08-07

- [Feat] add support for configuring scrape interval for target allocator prometheus custom resource
- [CHORE] - Updated target allocator version to 0.105.0 in values.yaml

## v0.0.93 / 2024-08-06

- [Feat] Add more defaults for fleet management preset

## v0.0.92 / 2024-08-05

- [Feat] add more system attributes to host entity event preset
- [Feat] Add fleet management preset

## v0.0.91 / 2024-08-05

- [Feat] add more attributes to host entity event preset

## v0.0.90 / 2024-07-31

- [:warning: CHANGE] [FEAT] Bump collector version to `0.106.1`. If you're using your custom configuration that relies on implicit conversion of types, please see the note about change in behavior in the [`UPGRADING.md`](./UPGRADING.md)
- [Fix] Mute process executable errors in host metrics

### v0.0.89 / 2024-07-29

- [Feat] add host entity event preset

### v0.0.88 / 2024-07-26

- [Feat] add kubernetes resource preset

### v0.0.87 / 2024-07-18

- [FEAT] Add process option to hostmetrics preset to scrape process metrics.

### v0.0.86 / 2024-07-08

- [FEAT] Update Windows collector image to `0.104.0`
- [FEAT] Update values file to be in sync with Linux agents.

### v0.0.85 / 2024-07-03

- [:warning: CHANGE] [FEAT] Bump collector version to `0.104.0`. If you are providing your own environemnt variables that are being expanded in the collector configuration, be sure to use the recommended syntax with the `env:` prefix (for example: `${env:ENV_VAR}` instead of just `${ENV_VAR}`). For more information see [here](https://github.com/open-telemetry/opentelemetry-collector-contrib/releases/tag/v0.104.0). The old way of setting environment variables will be removed in the near future.

### v0.0.84 / 2024-06-26

- [Fix] Add azure to resource detection processor

### v0.0.83 / 2024-06-26

- [Fix] Add cluster.name and resource detection processors to gateway-collector metrics

### v0.0.82 / 2024-06-26

- [Fix] Add k8s labels to gateway-collector metrics

### v0.0.81 / 2024-06-26

- [Fix] Allow configuring max_unmatched_batch_size in multilineConfigs. Default is changed to max_unmatched_batch_size=1.
- [Fix] Fix spanMetrics.spanNameReplacePattern preset does not work

### v0.0.80 / 2024-06-20

- [BREAKING] logging exporter is removed from default exporters list, since collector 0.103.0 removed it.

### v0.0.79 / 2024-06-06

- [FEAT] Update Target Allocator version to 0.101.0

### v0.0.78 / 2024-06-06

- [FEAT] Bump Collector to 0.102.1
- [FIX] Important: This version contains fix for cve-2024-36129. For more information see https://opentelemetry.io/blog/2024/cve-2024-36129/

### v0.0.77 / 2024-06-05

- [FIX] Fix target allocator add events and secrets permission

### v0.0.76 / 2024-06-03

- [FEAT] Add Kubernetes metadata to otel collector metrics

### v0.0.75 / 2024-06-03

- [FEAT] Add status_code to spanmetrics preset

### v0.0.74 / 2024-05-28

- [FEAT] Bump Collector to 0.101.0
- [FEAT] Allow setting dimensions to spanMetricsMulti preset

### v0.0.73 / 2024-05-28

- [FEAT] Bump Helm chart dependencies.
- [FEAT] Allowing loadBalancing presets dns configs (timout and resolver interval).

### v0.0.72 / 2024-05-16

- [FEAT] Bump Collector to 0.100.0
- [FEAT] Add container CPU throttling metrics
- [FEAT] Add k8s_container_status_last_terminated_reason metric to track OOMKilled events.

### v0.0.71 / 2024-05-06

- [Fix] reduceResourceAttributes preset will now work when metadata preset is manually set in processors.

### v0.0.70 / 2024-04-29

- [FEAT] Bump Collector to 0.99.0.
- [BREAKING] GRPC/HTTP client metrics are now reported only when using `detailed` level.

### v0.0.69 / 2024-04-17

- [Fix] When routing processor with batch is used make sure routing processor is last.

### v0.0.68 / 2024-04-04

- [FEAT] Add config for metrics expiration in span metrics presets
- [FEAT] Bump Collector to 0.97.0

### v0.0.67 / 2024-04-02

- [FIX] Operator generate CRD missing environment variables
- [FEAT] Add new reduceResourceAttributes preset, which removes uids and other unnecessary resource attributes from metrics.

### v0.0.66 / 2024-03-26

- [FEAT] add spanMetricsMulti preset, which allows to specify histogram buckets per application.

### v0.0.65 / 2024-03-19

- [FIX] logsCollection preset make force_flush_period configurable and disable it by default.

### v0.0.64 / 2024-03-15

- [FIX] Add logsCollection fix for empty log lines.

### v0.0.63 / 2024-03-12

- [FIX] Use default processing values for `tailsamplingprocessor`
- [FIX] Remove duplicated `tailsamplingprocessor` configuration; keep it only in the `tail-sampling-values.yaml` file

### v0.0.62 / 2024-03-07

- [:warning: CHANGE] [CHORE] Update collector to version `0.96.0`. If you are using the deprecated `spanmetricsprocessor`, please note it is no longer available in version `0.96.0`. Please use `spanmetricsconnector` instead or use our [span metrics preset](https://github.com/coralogix/telemetry-shippers/tree/master/otel-integration/k8s-helm#about-span-metrics)
- [CHORE] Update Windows collector image and version `0.96.0`
- [CHORE] Use the upstream image of target allocator instead of custom fork

### v0.0.61 / 2024-03-06

- [FEAT] Add support for multiline configs based on namespace name / pod name / container name.

### v0.0.60 / 2024-03-01

- [FEAT] Configure batch processor sizes with hard limit 2048 units
- [FIX] Ensure batch processors is always last in the pipeline

### v0.0.59 / 2024-03-01

- [CHORE] Add otel-integration version header to coralogix exporter

### v0.0.58 / 2024-02-21

- [Fix] Change default spanmetrics connector's buckets and extra dimensions.

### v0.0.57 / 2024-02-21

- [Fix] Bump otel-gateway's otlp server grpc request size limit to 20 mib

### v0.0.56 / 2024-02-13

- [CHORE] Bump windows image to 0.93.0 for windows values files.
- [Feat] Add example of windows tail sampling.

### v0.0.55 / 2024-02-12

- [Feat] Change default to enable collector logs.

### v0.0.54 / 2024-02-09

- [CHORE] Pull upstream changes
- [CHORE] Bump Collector to 0.93.0
- [Fix] Go memory limit fixes
- [Feat] Log Collector retry on failure enabled.

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
- [:warning: BREAKING CHANGE] [FEATURE] Add support for span metrics preset. This replaces the deprecated `spanmetricsprocessor` with `spanmetricsconnector`. The new connector is disabled by default, as opposed the replaces processor. To enable it, set `presets.spanMetrics.enabled` to `true`.

### v0.0.36 / 2023-11-15
- [FIX] Change statsd receiver port to 8125 instead of 8127

### v0.0.35 / 2023-11-14
- [FEATURE] Adds statsd receiver to listen for metrics on 8125 port.

### v0.0.34 / 2023-11-13
- [FIX] Remove Kube-State-Metrics receive_creator, which generated unnecessary configuration.

### v0.0.33 / 2023-11-08
- [FIX] Remove Kube-State-Metrics, as K8s Cluster Receiver provides all the needed metrics.

### v0.0.32 / 2023-11-03
- [FIX] Ensure correct order of processors for k8s deployment attributes.

### v0.0.31 / 2023-11-03
- [FIX] Fix scraping Kube State Metrics
- [CHORE] Update Collector to 0.88.0 (v0.76.0)
- [FIX] Fix consistent k8s.deployment.name attribute

### v0.0.30 / 2023-10-31
- [FEATURE] Add support for defining priority class

### v0.0.29 / 2023-10-31
- [FIX] Fix support for openshift

### v0.0.28 / 2023-10-30
- [CHORE] Update Collector to 0.87.0 (v0.75.0)

### v0.0.27 / 2023-10-30
- [CHORE] Update Collector to 0.86.0 (v0.74.0)

### v0.0.26 / 2023-10-30
- [CHORE] Upgrading upstream chart. (v0.73.7)

### v0.0.25 / 2023-10-26
- [CHORE] Remove unnecessary cloud resource detector configuration.

### v0.0.24 / 2023-10-26
- [FIX] service::pipelines::logs: references exporter "k8sattributes" which is not configured

### v0.0.23 / 2023-10-26
- [FEATURE] Add k8sattributes and resourcedetecion processor for logs and traces in agent.

### v0.0.22 / 2023-10-24
- [FEATURE] Add support for Windows node agent

### v0.0.21 / 2023-10-11

- [FIX] Fix missing `hostNetwork` field for CRD-based deployment
- [CHORE] Simplfy CRD override - put into a separate file

### v0.0.20 / 2023-10-06

- [CHORE] Bump Collector to 0.85.0

### v0.0.19 / 2023-10-05

- [CHORE] Bump Collector to 0.84.0

### v0.0.18 / 2023-10-04

- [FIX] hostmetrics don't scrape /run/containerd/runc/* for filesystem metrics

### v0.0.17 / 2023-09-29

- [FIX] Remove redundant `-agent` from `fullnameOverride` field of `values.yaml`

### v0.0.16 / 2023-09-28

- [FIX] Remove `k8s.pod.name`,`k8s.job.name` and `k8s.node.name` from subsystem attribute list

### v0.0.15 / 2023-09-15

- [FIX] Set k8s.cluster.name to all signals.
- [CHORE] Upgrading upstream chart. (v0.71.2)

### v0.0.14 / 2023-09-04

- [CHORE] Upgrading upstream chart. (v0.71.1)

### v0.0.13 / 2023-08-22

- [FIX] Change `k8s.container.name` to `k8s.pod.name` attribute

### v0.0.12 / 2023-08-21

- [FEATURE] Support host.id from system resource detector.

### v0.0.11 / 2023-08-18

- [CHORE] Upgrading upstream chart. (v0.71.0).
- [CHORE] Update Opentelemetry Collector 0.81.0 -> 0.83.0.
- [CHORE] Merges changes from upstream.

### v0.0.10 / 2023-08-14

- [FEATURE] Add CRD generation feature
- [FEATURE] Add MySQL preset

### v0.0.9 / 2023-08-11

- [CHORE] Upgrading upstream chart. (v0.70.1)

### v0.0.8 / 2023-08-11

- [CHORE] Upgrading upstream chart. (v0.69.0)

### v0.0.7 / 2023-08-11

- [FEATURE] Align `cx.otel_integration.name` with the new internal requirements

### v0.0.6 / 2023-08-08

- [CHORE] Bump Coralogix OpenTelemetry chart to `0.68.0`
- [FEATURE] Make `k8s.node.name` label the target node for Kubernetes node info metric

### v0.0.5 / 2023-08-04

- [FIX] Fix `kube-event` transfrom processor configuration to correctly filter log body keys

### v0.0.4 / 2023-08-03

- [FEATURE] Add cluster metrics related to allocatable resources (CPU, memory)
- [CHORE] Remove unused `cx.otel_integration.version` attribute
- [CHORE] Remove unused `enabled` parameter on `kube-state-metrics` config

### v0.0.3 / 2023-08-02

- [CHORE] Bump Coralogix OpenTelemetry chart to `0.67.0`

### v0.0.2 / 2023-08-02

- [FEATURE] Add `k8s.node.name` resource attribute to cluster collector
- [FEATURE] Override detection for cloud provider detectors
- [BUG] Fix ports configuration

### v0.0.1 / 2023-07-21

- [FEATURE] Add new chart
