# Changelog

## OpenTelemetry-Integration

### v0.0.266 / 2026-01-15
- [Fix] Remove unneeded `status_code="STATUS_CODE_UNSET"` label from non-span metrics such as hostmetrics or kubeletmetrics.

### v0.0.265 / 2026-01-15
- [Feat] Add cloud tags collection for Infra Explore by enabling `ec2.tags` and `azure.tags` in the `resourcedetection/entity` processor.
- [Feat] Add Azure cloud support for Infra Explore by mapping `azure.vm.size` to `host.type` in the host entity events pipeline when provider is Azure.

### v0.0.264 / 2026-01-13
- [Fix] Apply `presets.spanMetrics.histogramBuckets` value to `dbMetrics`.

### v0.0.263 / 2026-01-12
- [Feat] Add collector-based eBPF profiler configuration and docs, including OTLP header support.

### v0.0.262 / 2026-01-12
- [Change] Bump OBI image to v0.4.1

### v0.0.261 / 2026-01-08
- [Feature] Ensure new behaviors from span metrics connector, defined behind +connector.spanmetrics.useSecondAsDefaultMetricsUnit, +connector.spanmetrics.excludeResourceMetrics, +spanmetrics.statusCodeConvention.useOtelPrefix feature gates don't break backward compatibility.

1. Added add_resource_attributes: true to maintain resource attributes in span metrics
2. Added histogram.unit: ms to maintain millisecond units for duration metrics
3. Added OTTL transformations to convert new otel.status_code back to old status.code format with STATUS_CODE_* values

- [Feat] Add an `ebpfProfiler` preset that switches to the otelcol-ebpf-profiler distribution, creates a profiles-only pipeline, and wires the profiling receiver. Allows to configure intervals, thresholds, off-CPU, verbosity, tracers.
- [Feat] Add a `profilesK8sAttributes` preset to enrich profiles with Kubernetes attributes and map service.name from labels/metadata.
- [Feat] Add an `otlpExporter` preset to configure an OTLP endpoint with optional headers, plus pipeline selection.

- [Fix] Add missing field service.loadBalancerClass to support setups with AWS ALB Controller

### v0.0.260 / 2026-01-06
- [Fix] Remove unused `k8s_observer` extension from `kubernetesExtraMetrics` preset to avoid unnecessary API server load.

### v0.0.259 / 2026-01-05
- [CHORE] Update Target Allocator image to v0.141.0

### v0.0.258 / 2026-01-05
- [CHORE] Update Windows image to v0.142.0

### v0.0.257 / 2025-12-30
- [CHORE] Bump Collector to 0.142.0

### v0.0.256 / 2025-12-24
- [Feat] Add `provider` field to `reduceResourceAttributes` and `resourceDetection` presets for targeted cloud provider configuration.
- [Bug] Apply `resourceDetection` preset to `profiles`.
- [Feat] Add `dynamicSubsystemName` option to `journaldReceiver` preset to extract subsystem name from systemd unit name or syslog identifier.
- [Fix] Fix `macosSystemLogs` regex pattern to correctly parse multiline log entries.
- [Fix] Fix `macosSystemLogs` dynamic subsystem naming to use `service.name` instead of `cx.subsystem.name`.
- [Fix] Remove `nop` exporter and receiver from `profiles` pipeline when the `supervisor` and `profilesCollection` presets are enabled.

### v0.0.255 / 2025-12-22
- [Feat] Add support for custom pod labels on TargetAllocator pods via `targetAllocator.podLabels`.

### v0.0.254 / 2025-12-19
- [Fix] Add missing `node` to `k8s_observer` for `kubernetesApiServerMetrics` preset.
- [Fix] Add support for combining `profilesCollection` preset with `fleetManagement` preset.

### v0.0.253 / 2025-12-15
- [Feat] Add the `deltaToCumulative` preset to the agent so operators can opt into converting delta metrics before export.

### v0.0.252 / 2025-12-12
- [Feat] Add Context Propagation Mode option to OBI config, defaults to "http,tcp"

### v0.0.251 / 2025-12-12
- [Feat] PullPolicy Configuration for `coralogix-ebpf-profiler` helm chart

### v0.0.250 / 2025-12-12
- [CHORE] Bump Collector to 0.141.0
- [Feat] Add deltaToCumulative preset (disabled by default) to convert metrics from delta temporality to cumulative.
- [Feature] Add service.version to profile attributes when profilesCollection preset is enabled.
- [Feat] Add dynamicSubsystemName option to macosSystemLogs preset to control copying unit name to subsystem name.
- [Fix] Ensure logs/resource_catalog pipeline respects presets for metadata, kubernetesAttributes, and resourceDetection.
- [Fix] Fix logic to correctly respect region.enabled: false in resourceDetection preset.
- [Fix] Align macOS application naming attributes with the standalone distribution by using only service.name.
- [Feat] Allow disabling the resourcedetection/region processor in the resourceDetection preset.
- [Fix] Align macOS subsystem naming attributes with the standalone distribution by using only service.name.

### v0.0.249 / 2025-12-08
- [Feat] Bump OBI to [v0.3.0](https://github.com/open-telemetry/opentelemetry-ebpf-instrumentation/releases/tag/v0.3.0)

### v0.0.248 / 2025-12-08
- [Breaking] Split `kubernetesExtraMetrics` preset: now only handles cAdvisor metrics scraping. API server scraping moved to `kubernetesApiServerMetrics` preset.
- [Feat] Add `kubernetesApiServerMetrics` preset to scrape Kubernetes API server metrics separately from cAdvisor metrics.

### v0.0.247 / 2025-12-02
- [Feat] Enable the `transactions` preset for the otel agent by default.

### v0.0.246 / 2025-12-02
- [Change] Bump OBI image to v0.2.0
- [Fix] Fixes in OBI default config

### v0.0.245 / 2025-12-01
- [Fix] Increase the Supervisor config apply timeout to 30 seconds (previously 5 seconds). This should match the default heartbeat interval.

### v0.0.244 / 2025-11-26
- [Change] Disable database statement sanitization in the span metrics sanitization preset by default. Currently sanitization is over agressive and replaces everything with a *, instead of obfuscating sensitive data.
- [Feat] Add `nodeSelector` option to `targetAllocator` preset.

### v0.0.243 / 2025-11-26
- [Change] Narrow default span metrics database sanitization to SQL, Redis, and Memcached statements.
- [Fix] Grant EndpointSlice RBAC permissions when enabling the Kubernetes resolver for the loadbalancing exporter.

### v0.0.242 / 2025-11-25
- [Feature] add `k8s.container.name` attribute to profiles
- [Feature] update profiler to [v0.0.202547](https://github.com/open-telemetry/opentelemetry-ebpf-profiler/releases/tag/v0.0.202547) to support proto v1.9.0

### v0.0.241 / 2025-11-25
- [Fix] Fix cluster name rendering in Supervisor configuration.

### v0.0.240 / 2025-11-24
- [CHORE] Update Target Allocator image to v0.140.0
- [CHORE] Update Windows image to v0.140.1

### v0.0.239 / 2025-11-21
- [CHORE] Bump Collector to 0.140.1

### v0.0.238 / 2025-11-19
- [Fix] Add the `health_check` extension to the Supervisor minimal Collector configuration.

### v0.0.237 / 2025-11-17
- [Fix] Remove pipelines that have no exporters after presets are applied so limiting `presets.coralogixExporter.pipelines` to a subset no longer leaves invalid empty pipelines.

### v0.0.236 / 2025-11-13
- [Fix] Use new container image in the Supervisor preset hosted in Coralogix' JFrog instance.

### v0.0.235 / 2025-11-12
- [Fix] Default `deployment.environment.name` to `global.clusterName` when the resource detection preset's `deploymentEnvironmentName` stays empty and preserve it when span metrics' compact pipelines drop resource keys so the cluster identity remains set.

### v0.0.234 / 2025-11-11
- [Fix] Keep compact spanmetrics and database histograms by default by setting `dropHistogram` to `false`.
- [Feat] Make the `fleetManagement.supervisor` preset ship a minimal collector config that only wires the OpAMP extension so the supervisor can connect to the Coralogix OpAMP backend.

### v0.0.233 / 2025-11-07
- [Fix] Derive Coralogix application and subsystem names from `service.namespace` and `service.name` when using the standalone distribution.
- [Fix] Emit Coralogix OTLP headers with the `helm-otel-standalone` distribution tag when the standalone distribution is selected.
- [Feat] Add `filelogMulti` preset for configuring multiple filelog receivers with Coralogix resource annotations.
- [Feat] Allow `filelogMulti` receivers to derive Coralogix application and subsystem names from resource attributes after custom operators run.
- [Feat] Allow `additionalEndpoints` option to `coralogixExporter` preset to add additional Coralogix endpoints.
- [Feat] extend opamp extension and resource catalog exporter to support additional endpoints.
- [Feat] Allow `filelogMulti` preset receivers to configure multiline log parsing.
- [Feat] Allow setting custom non-identifying attributes for both supervisor and OpAMP extensions via `fleetManagement.customAttributes` preset.

### v0.0.232 / 2025-10-22
- [Feat] `opentelemetry-ebpf-instrumentation` - Increase http, postgres default buffer sizes, add graphql payload extraction

### v0.0.231 / 2025-10-21
- [Feat] Add `resource/metadata` processor to profiles pipeline when `profilesCollection` preset is enabled.
- [Feat] update `opentelemetry-ebpf-profiler` to commit [0018abf5](https://github.com/open-telemetry/opentelemetry-ebpf-profiler/commit/0018abf5f36d53f38eef235564b0acc42da6f69f) to support proto v1.8.0

### v0.0.230 / 2025-10-20
- [Feat] Add `prometheusMulti` preset for scraping multiple Prometheus targets with optional custom labels.
- [Fix] Emit Prometheus multi-target jobs using the provided target name and only apply CX labels when explicitly configured.
- [Chore] Standalone example enables the `prometheusMulti` preset with contrasting target configurations.
- [Feat] Add `journaldReceiver` preset for systemd journal logs with optional directory, unit, and match filters.
- [Feat] Allow conditional resource attribute removals in the `reduceResourceAttributes` preset via denylist entry conditions.
- [Feat] Add `spanMetricsSanitization` preset to provide span name, URL, and database statement sanitization when span metrics presets are enabled.

### v0.0.229 / 2025-10-16
- [FIX] compact metrics unit name change. compact_duration_count -> compact_duration_ms_count, compact_duration_sum -> compact_duration_ms_sum, db_compact_duration_count -> db_compact_duration_ms_count, compact_duration_sum -> compact_duration_ms_sum
- [Feat] Allow configuring resource detection detectors for environment and cloud metadata.
- [Feat] Add standalone distribution option that binds Prometheus endpoints to 0.0.0.0 and scrapes host metrics from the root filesystem.

### v0.0.228 / 2025-10-14
- [Feat] Enable compact metrics for span-derived database metrics by default.

### v0.0.227 / 2025-10-08
- [Feat] Enable the compact span metrics preset by default.
- [FIX] Route the logs router default path through a continuation stage so extra filelog operators always run and drop the now-redundant export noop stage.

### v0.0.226 / 2025-10-08
- [Feat] Enable the `k8sResourceAttributes` preset for the otel agent by default.

### v0.0.225 / 2025-10-07
- [CHORE] Bump Collector to 0.137.0

### v0.0.224 / 2025-09-24
- [CHORE] Bump Collector to 0.136.0

### v0.0.223 / 2025-09-18
- [Fix] filter k8s node on k8sattributes/profiles processor

### v0.0.222 / 2025-09-16
- [Feat] add spanmetrics.dbMetrics compact option.

### v0.0.221 / 2025-09-10
- [CHORE] Bump Collector to 0.135.0
- [Breaking] Otel Collector metrics have changed otelcol_processor_filter_logs.filtered => otelcol_processor_filter_logs.filtered_ratio, telcol_processor_filter_datapoints.filtered => otelcol_processor_filter_datapoints.filtered_ratio
- [CHORE] Updated Target Allocator to 0.132.0

### v0.0.220 / 2025-09-08
- [CHORE] Bump Collector to 0.134.1

### v0.0.219 / 2025-09-05
- [Feat] Coralogix exporter: add exporter helper settings (retry_on_failure, sending_queue); flatten values to `presets.coralogixExporter.retryOnFailure` and `sendingQueue`; add example and schema support.

### v0.0.218 / 2025-09-03
- [Fix] Fix quoting issue with EKS Fargate `collectionInterval`.
- [Fix] Fix `otel_annotations` field intendation for `k8sattributes/profiles`.
- [Feat] loadBalancing preset: add `pipelines` option to select pipelines (logs, metrics, traces, profiles). Default is ["traces"].
- [Feature] Profiling: add `serviceLabels` and `serviceAnnotations` options to `profilesCollection` preset, to allow for custom service name detection.

### v0.0.216 / 2025-08-29
- [Feat] Add support for EKS Fargate.
- [Feat] Add `eks` detector to `resource/region` processor.
- [Feat] Profiling: improve service name detection by otel conventions.

### v0.0.216 / 2025-08-19
- [Feat] Add Kubernetes service resolver to load balancing preset and required RBAC.

### v0.0.215 / 2025-08-12
- [Fix] Tail sampling values: correct Coralogix preset pipelines syntax.

### v0.0.214 / 2025-08-11
- [Feat] Add affinity, tolerations, and nodeSelector to the `opentelemetry-ebpf-instrumentation` k8s-cache deployment.

### v0.0.213 / 2025-08-08
- [Feat] Update Collector to v0.131.1

### v0.0.212 / 2025-08-07
- [Fix] Resource attributes of the Collector's logs in the `filelog` receiver are correctly set.

### v0.0.211 / 2025-08-07
- [Feat] update `opentelemetry-ebpf-profiler` to commit [b93e1ec4](https://github.com/open-telemetry/opentelemetry-ebpf-profiler/commit/b93e1ec4daedd7063c107162c146e3172de82e6e)
- [Feat] `opentelemetry-ebpf-profiler`: Remove k8s-watcher and redis componentes,
- [Feat] `opentelemetry-ebpf-profiler`: Service name and k8s attributes will be computed in collector using k8sAttributes and transform processors.

### v0.0.210 / 2025-08-07
- [Fix] `profilesCollection` preset correctly adds `coralogix` exporter to `profiles` pipeline.

### v0.0.209 / 2025-08-07
- [Feat] add option to drop compact duration histogram in spanMetrics preset.

### v0.0.208 / 2025-08-05
- [Fix] `headSampling` preset correctly removes `coralogix` exporter from the `traces` pipeline.
- [Feat] Add compactMetrics option to spanMetrics preset.

### v0.0.207 / 2025-08-05
- [Feat] remove `coralogix-ebpf-agent` subchart, as now we recommend using `opentelemetry-ebpf-instrumentation` chart.

### v0.0.206 / 2025-08-04

- [Feat] Add k8sattributes support for profiles.

### v0.0.205 / 2025-07-28
- [Feat] Add support for profiles in the `reduceResourceAttributes` preset.
- [Feat] Add `k8s.container.restart_count` to the `reduceResourceAttributes` preset.

### v0.0.204 / 2025-07-28
- [Feat] Use networkMode in ipv6-values.yaml

### v0.0.203 / 2025-07-24
- [Fix] Correct transform rule for `otelcol_otelsvc_k8s_pod_deleted_ratio` metric.
- [Feat] Remove the attribute `cx.otel_integration.name` through the `reduceResourceAttributes` preset.
- [Feat] Add more attribute coming from auto-instrumentation SDKs to the `reduceResourceAttributes` preset.
- [Feat] Add additional Prometheus transform rules for collector metrics preset.
- [Feat] Fail installation if kubernetesResources preset is enabled in daemonset mode.
- [Feat] Set spanMetrics aggregationCardinalityLimit default to 100000.
- [Feat] Update Collector to v0.130.1
- [Feat] Add `reduceLogAttributes` preset to remove specified log record attributes from collected logs.
- [Fix] Set `error_mode` to `silent` for the transformations of the `reduceResourceAttributes` and `reduceLogAttributes` presets.
- [Feat] Add `host.image.id` to the `reduceResourceAttributes` preset.
- [Fix] `command.name` override put back in place.
- [Fix] `k8sResourceAttributes` preset works correctly when the `fleetManagement` preset is enabled.
- [Feat] The `reduceResourceAttributes` preset now also removes attributes from traces and logs pipelines.
- [Feat] The `reduceResourceAttributes` preset now removes a few more attributes.
- [Fix] Skip prometheus receiver from collectorMetrics preset when PodMonitor or ServiceMonitor is enabled
- [Fix] Remove extra blank lines when rendering container ports
- [Feat] Allow disabling the /var/lib/dbus/machine-id mount via `presets.resourceDetection.dbusMachineId.enabled`
- [Feat] Add transactions preset to group spans into transactions and enable Coralogix transaction processor
- [Feat] Add `networkMode` option to configure IPv4 or IPv6 endpoints
- [Feat] Update Collector to v0.130.0

### v0.0.202 / 2025-07-14
- [Feat] Add E2E test for hostEntityEvents preset.

### v0.0.201 / 2025-07-13
- [Feat] Bump `opentelemetry-ebpf-instrumentation` version to `0.1.2`

### v0.0.200 / 2025-07-10
- [Fix] Remove deprecated match_once key from `spanMetricsMultiConfig` config.

### v0.0.199 / 2025-07-09
- [Feat] add k8s ipv6 support for ebpf-profiler sub-chart, fix ipv6-values.yaml to support change in address fields.

### v0.0.198 / 2025-07-09
- [Fix] Apply `transform/prometheus` rule only for metrics from the Collector itself.

### v0.0.197 / 2025-07-04
- [Feat] Support global `deploymentEnvironmentName` for the resource detection preset.
- [Feat] Update Collector to v0.129.1

### v0.0.196 / 2025-07-03
- [Feat] Add new variable `presets.coralogixExporter.pipelines` as an `array[string]` to allow enabling exporter on 2 pipelines at once. The old variable `presets.coralogixExporter.pipeline` is still available, but deprecated
- [Feat] Add coralogix-operator subchart.

### v0.0.195 / 2025-07-02
- [Fix] Support templating for `presets.resourceDetection.deploymentEnvironmentName`.

### v0.0.194 / 2025-06-27
- [Feat] Upgrade OpenTelemetry Collector to `0.116.1`

### v0.0.193 / 2025-06-22
- [Feat] bump opentelemetry-ebpf-profiler version.

### v0.0.192 / 2025-06-17
- [Feat] bump opentelemetry-ebpf-instrumentation version.

### v0.0.191 / 2025-06-16
- [Fix] Recover metrics `k8s_node_allocatable_cpu__cpu` and `k8s_node_allocatable_memory__By` in `k8sclusterreceiver` on the collector side

### v0.0.190 / 2025-06-15
- [Feat] Add opentelemetry-ebpf-instrumentation subchart.

### v0.0.189 / 2025-06-13
- [Fix] Fix `command` template helper when using the Supervisor preset.

### v0.0.188 / 2025-06-12
- [Fix] Fix `image` template helper when using the Supervisor preset and when using the Collector CRDs.

### v0.0.187 / 2025-06-12
- [Feat] Add an alpha `supervisor` preset under the `fleetManagement` preset
- [Feat] Certain attributes related to the `fleetManagement` preset are now added
  as non-identifying attributes even when `k8sResourceAttributes` preset is disabled.

### v0.0.186 / 2025-06-09
- [Feat] allow `dropManagedFields`, `periodicCollection` and `transformStatements` in preset.kubernetesResources

### v0.0.185 / 2025-06-06
- [Feat] Allow filtering Kubernetes Resources using custom OTTL statements via `presets.kubernetesResources.filterStatements`

### v0.0.184 / 2025-06-06
- [Feat] Use semconv preset in agent instead of hardcoded version in values.yaml
- [Fix] gke/autopilot to not use hostEntity preset and resourceDetection preset.

### v0.0.183 / 2025-06-05
- [Feat] Use newly added presets in windows instead of hardcoding stuff in values.yaml

### v0.0.182 / 2025-06-05
- [Fix] Cluster collector k8scluster shoudl not filter on NODE level
- [Fix] fleetManagement preset automatically injects KUBE_NODE_NAME env variable.
- [Fix] Agent k8scluster should filter on NODE level

### v0.0.182 / 2025-06-05
- [Feat] Use newly added presets in receiver instead of hardcoding stuff in values.yaml

### v0.0.181 / 2025-06-05
- [Fix] Disable Coralogix exporter for tracing pipeline when tail-sampling is used.

### v0.0.180 / 2025-06-04
- [Feat] Use newly added presets instead of hardcoding stuff in values.yaml

### v0.0.179 / 2025-05-30
- [Feat] Use newly added presets instead of hardcoding stuff in values.yaml

### v0.0.178 / 2025-05-22
- [Feat] Update windows and target-allocator image

### v0.0.177 / 2025-05-22
- [Feat] Enable spanmetrics by default

### v0.0.176 / 2025-05-19
- [Feat] Update Collector to v0.126.0
- [Update] `kubeletstatsreceiver`: set `collect_all_network_interfaces` on `pods`

### v0.0.175 / 2025-05-19
- [Fix] Fix utilization metric name and unit in `kubeletMetrics` preset to keep the metrics' backward compatibility for dashboards

### v0.0.174 / 2025-05-16
- [Chore] Remove unnecessary config form values.yaml
- [Feat] Move to jaegerReceiver preset instead of configuring jaeger ports and receivers directly
- [Feat] Move to zipkinReceiver preset instead of configuring zipkin ports and receivers directly
- [Feat] Move to resourceDetection preset instead of configuring resourcedetection manually.

### v0.0.173 / 2025-05-16
- [Chore] Remove unnecessary config form values.yaml

### v0.0.172 / 2025-05-15
- [Feat] Update Collector to v0.125.0
- [Fix] Configure `kubeletstatsreceiver` to enable network metrics collection from all available interfaces on Node level

### v0.0.171 / 2025-05-09
- [Fix] Fix target allocator namespace.
- [Fix] Fix rendering of securityContext and podSecurityContext for Collector CRD.
- [Feat] Add collectorMetrics preset to collect collector's own metrics using Prometheus receiver
- [Feat] Add E2E test for the OTEL Operator

### v0.0.170 / 2025-04-25
- [Feat] Update Collector to v0.124.1
- [Breaking] We are moving to ghcr image registry instead of dockerhub, as OTel doesn't use dockerhub due to rate limits. Ref https://github.com/open-telemetry/opentelemetry-collector-releases/releases/tag/v0.123.1

### v0.0.169 / 2025-04-22
- [Feat] Add scrapeAll metrics support for collector

### v0.0.168 / 2025-04-14
- [Feat] Add db dimensions to spanmetrics
- [Fix] fix dbMetrics use db.collection.name instead of db.collection_name

### v0.0.167 / 2025-04-11
- [Feat] Update Collector to v0.123.0

### v0.0.166 / 2025-04-08
- [Feat] Add ebpf-profiler subchart.

### v0.0.165 / 2025-04-04
- [Feat] Review otel-integration readme

### v0.0.164 / 2025-04-04
- [Feat] Update Collector to v0.122.1

### v0.0.163 / 2025-04-04
- [Feat] Add MongoDB support to coralogix-ebpf-agent.

### v0.0.162 / 2025-04-02
- [Fix] Filter only Pods from standard kubernetes workloads in kubernetesResource presets.

### v0.0.161 / 2025-04-01
- [Fix] Add extraDimensions support for dbMetrics in spanMetrics preset

### v0.0.160 / 2025-03-31
- [Feat] Add extraDimensions support for dbMetrics in spanMetrics preset
- [Fix] Configure hostEntityEvents preset to require hostMetrics preset to be enabled

### v0.0.159 / 2025-03-25
- [Revert] Remove `ebpf-profiler` as a subchart

### v0.0.158 / 2025-03-21
- [Fix] OpentelemetryCollector crd generation

### v0.0.157 / 2025-03-19
- [Feat] Use global k8stest package

### v0.0.156 / 2025-03-17
- [Feat] Enable fleetmanagement preset by default

### v0.0.155 / 2025-03-12
- [Fix] Add missing service_instance_id in metrics
- [docs] Add headsampling docs

### v0.0.154 / 2025-03-12
- [Feat] Update windows image to v0.121.0
- [Feat] Add ebpf-profiler subchart.

### v0.0.153 / 2025-03-06
- [Feat] Update Collector to v0.121.0
- [Feat] Update Target Allocator to v0.119.0
- [Feat] Add headSampling preset to configure probabilistic sampling for traces

### v0.0.152 / 2024-03-05

- [Feat] Allow adding tolerations to coralogix-ebpf-agent

### v0.0.151 / 2024-03-04

- [Fix] Add Bottlerocket support to coralogix-ebpf-agent

### v0.0.150 / 2025-02-29

- [Feat] Upgrade OpenTelemetry Collector to `0.120.0`

### v0.0.149 / 2025-02-27

- [Feat] Upgrade OpenTelemetry Collector to `0.119.0`

### v0.0.148 / 2025-02-20

- [Fix] Filter only Pods from standard kubernetes workloads in kubernetesResource presets.

### v0.0.147 / 2025-02-19

- [Fix] Add error_mode: ignore to transform/semconv.

### v0.0.146 / 2025-02-19

- [Feat] Automatically convert http.request.method to http.method for spans

### v0.0.145 / 2025-02-18

- [Feat] Add agent type and service instance id to Otel Collector metrics
- [Fix] OpenTelemetry Windows error: ImagePullBackOff

### v0.0.144 / 2025-02-18
- [Fix] `spanMetrics.transformStatements` are correctly created even when
  `spanMetrics.dbMetrics` is not enabled.

### v0.0.143 / 2025-02-05

- [Feat] Add support for custom autoscaling mode alongside hpa mode

### v0.0.142 / 2025-02-05

- [Fix] Remove k8s_cluster receiver from Opentelemetry Cluster Collector metrics
  pipeline. The receiver is managed by clusterMetrics preset.

### v0.0.141 / 2025-02-05

- [Fix] Prioritize memory limiter processor in all pipelines.

### v0.0.140 / 2025-02-04

- [Feat] Upgrade OpenTelemetry Collector to `0.118.0`
- [Feat] Upgrade Target Allocator to `0.117.0`

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
