# OpenTelemetry Integration

The OpenTelemetry Integration consists of two main compoenents, that provide our users with full fledged integration for their Kubernetes cluster - the [OpenTelemetry Agent](#opentelemetry-agent) and [OpenTelemetry Cluster Collector](#opentelemetry-cluster-collector). Depending on your needs, you can deploy both components (default behavior) or decide to disable eihter one under the `opentelemetry-agent` or `opentelemetry-cluster-collector` sections in the `values.yaml` file.

### OpenTelemetry Operator (for CRD users)

If you wish to use this Helm chart as an `OpenTelemetryCollector` CRD, you will need to have the OpenTelemetry Operator installed in your cluster. Please refer to the [OpenTelemetry Operator documentation](https://github.com/open-telemetry/opentelemetry-operator/blob/main/README.md) for full details.

We recommend to install the operator with the help of the community Helm charts from the [OpenTelemetry Helm Charts](https://github.com/open-telemetry/opentelemetry-helm-charts/tree/main/charts/opentelemetry-operator) repository.

Content:
1. [Components](#components)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [How to use it](#how-to-use-it)
5. [Performance of the Collector](#performance-of-the-collector)
6. [Infrastructure Monitoring](#infrastructure-monitoring)
7. [Integration presets](#integration-presets)
8. [Dependencies](#dependencies)

# Components

## OpenTelemetry Agent

For the agent component, the collector will be deployed as a daemonset, meaning the collector will run as an `agent` on each node. Agent runs in host network mode allowing you to easily send application telemetry data.

The included agent provides:

- [Coralogix Exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/coralogixexporter) - Coralogix exporter is preconfigured to enrich data using Kubernetes Attributes, which allows quick correlation of telemetry signals using consistent ApplicationName and SubsytemName fields.
- [Kubernetes Attributes Processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/k8sattributesprocessor) Kubernetes Attributes Processor, enriches data with Kubernetes metadata, such as Deployment information.
- [Kubernetes Log Collection](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/filelogreceiver) - native Kubernetes Log collection with Opentelemetry Collector. No need to run multiple agents such as fluentd, fluent-bit or filebeat.
- [Host Metrics](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/hostmetricsreceiver) - native Linux monitor resource collection agent. No need to run Node exporter or vendor agents.
- [Kubelet Metrics](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/kubeletstatsreceiver) - Fetches running container metrics from the local Kubelet.
- [OTLP Metrics](https://github.com/open-telemetry/opentelemetry-collector/blob/main/receiver/otlpreceiver/README.md) - Send application metrics via OpenTelemetry protocol.
- Traces - You can send data in various format, such as [Jaeger](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/jaegerreceiver), [OpenTelemetry Protocol](https://github.com/open-telemetry/opentelemetry-collector/blob/main/receiver/otlpreceiver/README.md) or [Zipkin](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/zipkinreceiver).
- [Span Metrics](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/connector/spanmetricsconnector/README.md) - Optional Traces are converted to Requests, Duration and Error metrics using spanmetrics connector.
- [Zpages Extension](https://github.com/open-telemetry/opentelemetry-collector/tree/main/extension/zpagesextension) - You can investigate latency and error issues by navigating to Pod's localhost:55516 web server. Routes are desribed in [OpenTelemetry documentation](https://github.com/open-telemetry/opentelemetry-collector/tree/main/extension/zpagesextension#exposed-zpages-routes)

## OpenTelemetry Cluster Collector

This cluster collector provides:

- [Coralogix Exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/coralogixexporter) - Coralogix exporter is preconfigured to enrich data using Kubernetes Attributes, which allows quick correlation of telemetry signals using consistent ApplicationName and SubsytemName fields.
- [Cluster Metrics Receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8sclusterreceiver) - The Kubernetes Cluster receiver collects cluster-level metrics from the Kubernetes API server.
- [Kubernetes Events Receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8seventsreceiver) - The Kubernetes Events receiver collects events from the Kubernetes API server. See [Kubernetes Events](#kubernetes-events) for more information.
- Kubernetes Extra Metrics - This preset enables collection of extra Kubernetes related metrics, such as node information, pod status or container I/O metrics. These metrics are collected in particular for the [Kubernetes Dashboard](#kubernetes-dashboard).
- [Integrations presets](#integration-presets) - This chart provides support to integrate with various applications running on your cluster to monitor them out of the box.

## Kubernetes Dashboard

This chart will also collect, out of the box, all the metrics necessary for [Coralogix Kubernetes Monitoring](https://coralogix.com/docs/apm-kubernetes/), which will allow you to monitor your Kubernetes cluster and applications.

**Please be aware** that certain metrics collected by for the dashboard have high cardinality, which means that the number of unique values for a given metric is high and might result in higher costs connected with metrics ingestion and storage. This is applies in particular to the pod related metrics `kube_pod_status_reason`, `kube_pod_status_phase` and `kube_pod_status_qos_class`.

If you do not require to collect these metrics, you can disable them by setting `global.extensions.kubernetesDashboard.enabled` to `false` in the `values.yaml` file.

## Metrics

OpenTelemetry integration collects metrics from various sources. You can see the list of metrics and their labels in OpenTelemetry Collector contrib receiver documentation:

- Kubernetes Cluster Receiver - https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/receiver/k8sclusterreceiver/documentation.md
- Kubelet Stats Receiver - https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/receiver/kubeletstatsreceiver/metadata.yaml
- Host Metrics Receiver - https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/hostmetricsreceiver

Additionally, we use [k8sattributes processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/k8sattributesprocessor) and [resource detection processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/resourcedetectionprocessor) to add more metadata labels.

For Kubernetes Dashboard we also use [Prometheus receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/receiver/prometheusreceiver/README.md) to scrape Kubernetes API Server and [Kubelet cAdvisor](https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/) endpoints.

Note: OpenTelemetry metrics are converted to Prometheus format following [OpenTelemetry specification](https://opentelemetry.io/docs/specs/otel/compatibility/prometheus_and_openmetrics/#otlp-metric-points-to-prometheus)

## Custom Metrics

OpenTelemetry Integration additionally adds these custom metrics:

### kube_pod_status_qos_class

Provides information about Pod QOS class.

| Metric Type | Value | Labels |
|-------------|-------|--------|
| Gauge       | 1     | reason |

### kube_pod_status_reason

Provides information about Kubernetes Pod Status.

| Metric Type | Value | Labels |
|-------------|-------|--------|
| Gauge       | 1     | reason |

Example reason label keys: Evicted, NodeAffinity, NodeLost, Shutdown, UnexpectedAdmissionError

### kube_node_info

Provides information about Kubernetes Node.

| Metric Type | Value | Labels              |
|-------------|-------|---------------------|
| Gauge       | 1     | k8s.kubelet.version |

### k8s.container.status.last_terminated_reason

Provides information about Pod's last termination.

| Metric Type | Value | Labels |
|-------------|-------|--------|
| Gauge       | 1     | reason |

Example reason label keys: OOMKilled

### kubernetes_build_info

Provides information about Kubernetes version.

### Container Filesystem usage metrics

- container_fs_writes_total
- container_fs_reads_total
- container_fs_writes_bytes_total
- container_fs_reads_bytes_total
- container_fs_usage_bytes

### CPU throttling metrics

- container_cpu_cfs_periods_total
- container_cpu_cfs_throttled_periods_total

# Prerequisites

Make sure you have at least these version of the following installed:

- Kubernetes 1.24+
- Helm 3.9+

### Secret Key

Follow the [private key docs](https://coralogix.com/docs/private-key/) tutorial to obtain your secret key tutorial to obtain your secret key.

OpenTelemetry Agent require a `secret` called `coralogix-keys` with the relevant `private key` under a secret key called `PRIVATE_KEY`, inside the `same namespace` that the chart is installed in.

```bash
kubectl create secret generic coralogix-keys \
  --from-literal=PRIVATE_KEY=<private-key>
```

The created secret should look like this:

```yaml
apiVersion: v1
data:
  PRIVATE_KEY: <encrypted-private-key>
kind: Secret
metadata:
  name: coralogix-keys
  namespace: <the-release-namespace>
type: Opaque 
```

# Installation

> [!NOTE] With some Helm version (< `v3.14.3`), users might experience multiple warning messages during the installation about following:
>
> ```
> index.go:366: skipping loading invalid entry for chart "otel-integration" \<version> from \<path>: validation: more than one dependency with name or alias "opentelemetry-collector"
>
> ```
>
> This is due to a validation bug in Helm (see this [issue](https://github.com/helm/helm/issues/12748)). This does not affect the installation process and the chart will be installed successfully. If you do not wish to see these warnings, we recommend either upgrading to the latest Helm version, or downgrading to a version not affected by the issue.

First make sure to add our Helm charts repository to the local repos list with the following command:

```bash
helm repo add coralogix-charts-virtual https://cgx.jfrog.io/artifactory/coralogix-charts-virtual
```

In order to get the updated Helm charts from the added repository, please run:

```bash
helm repo update
```

Install the chart:

```bash
helm upgrade --install otel-coralogix-integration coralogix-charts-virtual/otel-integration \
  --render-subchart-notes -f values.yaml
```

### Providing own array values for `extraEnvs`, `extraVolumes` or `extraVolumeMounts`

If you'd like to provide your own overrides for array values such as `extraEnvs`, `extraVolumes` or `extraVolumeMounts`, please beware that Helm does not support merging arrays, but instead the arrays will be nulled out (see this [issue](https://github.com/helm/helm/issues/3486) for more). In case you'd like to provide your own values for these arrays, make sure that you first **copy over any existing array values** from the provided `values.yaml` file.

### Generating OpenTelemetryCollector CRD for OpenTelemetry Operator users

If you wish to deploy the `otel-integration` using the OpenTelemetry Operator, you can generate an `OpenTelemetryCollector` CRD. You might want to do this if you'd like to take advantage of some advanced features provided by the operator, such as automatic collector upgrade or CRD-defined auto-instrumentation.

For full details on how to install and use the operator, please refer to the [OpenTelemetry Operator documentation](https://github.com/open-telemetry/opentelemetry-operator/blob/main/README.md).

First make sure to add our Helm charts repository to the local repos list with the following command:

```bash
helm repo add coralogix-charts-virtual https://cgx.jfrog.io/artifactory/coralogix-charts-virtual
```

In order to get the updated Helm charts from the added repository, please run:

```bash
helm repo update
```

Install the chart with the CRD `values-crd-override.yaml` file. You can either provide the global values (secret key, cluster name) by adjusting the main `values.yaml` file and then passing the `values.yaml` file to the `helm upgrade` command as following:

```bash
helm upgrade --install otel-coralogix-integration coralogix-charts-virtual/otel-integration \
  --render-subchart-notes -f values.yaml -f values-crd-override.yaml
```

Or you can provide the values directly in the command line by passing them with the `--set` flag:

```bash
helm upgrade --install otel-coralogix-integration coralogix-charts-virtual/otel-integration \
  --render-subchart-notes -f values-crd-override.yaml --set global.clusterName=<cluster_name> --set global.domain=<domain>
```

> [!NOTE] Users might experience multiple warning messages during the installation about following:
>
> ```
> Warning: missing the following rules for namespaces: [get,list,watch]
> ```
>
> This is due to a bug in Opentelemetry (see this [issue](https://github.com/open-telemetry/opentelemetry-operator/issues/2685)). This does not affect the installation process and the chart will be installed successfully.

### Enabling Tail Sampling

If you want to use [Tail Sampling](https://opentelemetry.io/docs/concepts/sampling/#tail-sampling) to reduce the amount of traces using [tail sampling processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/tailsamplingprocessor) you can install `otel-integration` using `tail-sampling-values.yaml` values. For example:

```bash
helm repo add coralogix-charts-virtual https://cgx.jfrog.io/artifactory/coralogix-charts-virtual

helm upgrade --install otel-coralogix-integration coralogix-charts-virtual/otel-integration \
  --render-subchart-notes -f tail-sampling-values.yaml
```

This change will configure otel-agent pods to send span data to coralogix-opentelemetry-gateway deployment using [loadbalancing exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/loadbalancingexporter). Make sure to configure enough replicas and resource requests and limits to handle the load. Next, you will need to configure [tail sampling processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/tailsamplingprocessor) policies with your custom tail sampling policies.

When running in Openshift make sure to set `distribution: "openshift"` in your `values.yaml`. When running in Windows environments, please use `values-windows-tailsampling.yaml` values file.

### Deploying Central Collector Cluster for Tail Sampling

If you want to deploy OpenTelemetry Collector in a seperate "central" Kubernetes Cluster, that receives telemetry data via OTLP receivers and does [Tail Sampling](https://opentelemetry.io/docs/concepts/sampling/#tail-sampling) you can install `otel-integration` using `central-tail-sampling-values.yaml` values file. Check the values file for configuration.

This will deploy two deployments:
- opentelemetry-receiver - responsible for receiving otlp data, pushing metrics and logs to Coralogix and loadbalancing spans to opentelemetry-gateway deployment.
- opentelemetry-gateway - a service that receives span data and does Tail Sampling decisions.

The opentelemetry-receiver will need to be exposed to other Kubernetes Clusters for sending data. You can do that by using service of type LoadBalancer, configuring Ingress object, or manually configuring your load balancer. Also, make sure to configure enough replicas and resource requests and limits to handle the load. Next, you will need to configure [tail sampling processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/tailsamplingprocessor) policies with your custom tail sampling policies.

```bash
helm repo add coralogix-charts-virtual https://cgx.jfrog.io/artifactory/coralogix-charts-virtual

helm upgrade --install otel-coralogix-central-collector coralogix-charts-virtual/otel-integration \
  --render-subchart-notes -f central-tail-sampling-values.yaml
```

Once you deploy it, you can validate by sending some otlp data to opentelemetry-receiver Service and checking Coralogix for spans. This can be done via telemetrygen:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: telemetrygen-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: telemetrygen
  template:
    metadata:
      labels:
        app: telemetrygen
    spec:
      containers:
      - name: telemetrygen
        image: ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest
        args:
          - "traces"
          - "--otlp-endpoint=coralogix-opentelemetry-receiver:4317"
          - "--otlp-insecure"
          - "--rate=10"
          - "--duration=120s"
EOF
```

Next, you will need to configure regular `otel-integration` deployment to send data to Central Collector Cluster:

```bash
helm upgrade --install otel-coralogix-integration coralogix-charts-virtual/otel-integration \
  --render-subchart-notes -f central-agent-values.yaml
```

#### Why am I getting ResourceExhausted errors when using Tail Sampling?

Typically, the errors look like this:

```
not retryable error: Permanent error: rpc error: code = ResourceExhausted desc = grpc: received message after decompression larger than max (5554999 vs. 4194304)
```

By default, OTLP Server has a single grpc request size 4MiB limit. This limit might breached when openetelemtry-agent sends the trace data using loadbalancing exporter to the gateway's OTLP Server. To fix this you should change the limit to a bigger value. For example:

```
receivers:
  otlp:
    protocols:
      grpc:
        max_recv_msg_size_mib: 20
```

References:
- OTLP Receiver config - https://github.com/open-telemetry/opentelemetry-collector/blob/main/receiver/otlpreceiver/README.md
- GRPC settings for this config - https://github.com/open-telemetry/opentelemetry-collector/blob/main/config/configgrpc/README.md#server-configuration
- Default msg size limit of GRPC servers - https://pkg.go.dev/google.golang.org/grpc#MaxRecvMsgSize

### Enabling scraping of Prometheus custom resources (`ServiceMonitor` and `PodMonitor`)

If you're leveraging the Prometheus Operator custom resources (`ServiceMonitor` and `PodMonitor`) and you would like to keep using them with the OpenTelemetry collector, you can enable the scraping of these resources by a special, optional component called target allocator. This feature is disabled by default and can be enabled by setting the `opentelemetry-agent.targetAllocator.enabled` value to `true` in the `values.yaml` file.

If enabled, the target allocator will be deployed as a separate deployment in the same namespace as the collector. It will be responsible for allocating targets for the agent collector on each node, to scrape targets that reside on the given node (a form of simple sharding). If needed, you can run multiple instances of the target allocator for high availability. This can be achieved by setting the `opentelemetry-agent.targetAllocator.replicas` value to a number greater than 1.

You can specify the preferred scrape interval for the Prometheus Custom Resource by setting `opentelemetry-agent.targetAllocator.prometheusCR.scrapeInterval`, the default is `30s`

For more details on Prometheus custom resources and target allocator see the documentation [here](https://github.com/open-telemetry/opentelemetry-operator/tree/main/cmd/otel-allocator#discovery-of-prometheus-custom-resources).

Note: OpenTelemetry Collector self-monitoring is currently not working due to Prometheus Receiver bug (https://github.com/open-telemetry/opentelemetry-operator/issues/3034), for now make sure to enable PodMonitor and metrics port to collect Collector metrics.

### Installing the chart on clusters with mixed operating systems (Linux and Windows)

Installing `otel-integration` is also possible on clusters that support running Windows workloads on Windows node alongside Linux nodes (such as [EKS](https://docs.aws.amazon.com/eks/latest/userguide/windows-support.html), [AKS](https://learn.microsoft.com/en-us/azure/aks/windows-faq?tabs=azure-cli) or [GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-cluster-windows)). The collector will be installed on Linux nodes, as these components are supported only on Linux operating systems. Conversely, the agent will be installed on both Linux and Windows nodes as a daemonset, in order to collect metrics for both operating systems. In order to do so, the chart needs to be installed with few adjustments.

Depending on your Windows server version, you might need to adjust the image you are using with the Windows agent. The default image is `coralogixrepo/opentelemetry-collector-contrib-windows:<semantic_version>`. For Windows 2022 servers, please use `coralogixrepo/opentelemetry-collector-contrib-windows:<semantic_version>-windows2022` version. You can do this by adjusting the `opentelemetry-agent-windows.image.tag` value in the `values-windows.yaml` file.

First make sure to add our Helm charts repository to the local repos list with the following command:

```bash
helm repo add coralogix-charts-virtual https://cgx.jfrog.io/artifactory/coralogix-charts-virtual
```

In order to get the updated Helm charts from the added repository, please run:

```bash
helm repo update
```

Install the chart with the CRD `values-windows.yaml` file. You can either provide the global values (secret key, cluster name) by adjusting the main `values.yaml` file and then passing the `values.yaml` file to the `helm upgrade` command as following:

```bash
helm upgrade --install otel-coralogix-integration coralogix-charts-virtual/otel-integration \
  --render-subchart-notes -f values.yaml -f values-windows.yaml
```

Or you can provide the values directly in the command line by passing them with the `--set` flag:

```bash
helm upgrade --install otel-coralogix-integration coralogix-charts-virtual/otel-integration \
  --render-subchart-notes -f values-windows.yaml --set global.clusterName=<cluster_name> --set global.domain=<domain>
```

### Installing the chart on GKE Autopilot clusters.

GKE Autopilot has limited access to host filesystems, host networking and host ports. Due to this some features of OpenTelemetry Collector do not work. More information about limitations is available in [GKE Autopilot security capabilities document](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-security)

Notable important differences from regular `otel-integration` are:
- Host metrics receiver is not available, though you still get some metrics about the host through `kubeletstats` receiver.
- Kubernetes Dashboard does not work, due to missing Host Metrics.
- Host networking and host ports are not available, users need to send tracing spans through Kubernetes Service. The Service uses `internalTrafficPolicy: Local`, to send traffic to locally running agents.
- Log Collection works, but does not store check points. Restarting the agent will collect logs from the beginning.

To install otel-integration to GKE/Autopilot follow these steps:

First make sure to add our Helm charts repository to the local repos list with the following command:

```bash
helm repo add coralogix-charts-virtual https://cgx.jfrog.io/artifactory/coralogix-charts-virtual
```

In order to get the updated Helm charts from the added repository, please run:

```bash
helm repo update
```

Install the chart with the CRD `gke-autopilot-values.yaml` file. You can either provide the global values (secret key, cluster name) by adjusting the main `values.yaml` file and then passing the `values.yaml` file to the `helm upgrade` command as following:

```bash
helm upgrade --install otel-coralogix-integration coralogix-charts-virtual/otel-integration \
  --render-subchart-notes -f values.yaml -f gke-autopilot-values.yaml
```

Or you can provide the values directly in the command line by passing them with the `--set` flag:

```bash
helm upgrade --install otel-coralogix-integration coralogix-charts-virtual/otel-integration \
  --render-subchart-notes -f gke-autopilot-values.yaml --set global.clusterName=<cluster_name> --set global.domain=<domain>
```

# How to use it

## Available Endpoints

Applications can send OTLP Metrics and Jaeger, Zipkin and OTLP traces to the local nodes, as `otel-agent` is using hostNetwork .

| Protocol              | Port  |
|-----------------------|-------|
| Zipkin                | 9411  |
| Jaeger GRPC           | 6832  |
| Jaeger Thrift binary  | 6832  |
| Jaeger Thrift compact | 6831  |
| Jaeger Thrift http    | 14268 |
| OTLP GRPC             | 4317  |
| OTLP HTTP             | 4318  |

### Example Application environment configuration

The following code creates a new environment variable (`NODE`) containing the node's IP address and then uses that IP in the `OTEL_EXPORTER_OTLP_ENDPOINT` environment variable. This ensures that each instrumented pod will send data to the local OTEL collector on the node it is currently running on.

```yaml
env:
  - name: NODE
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://$(NODE):4317"
```

### About global collection interval

The global collection interval (`global.collectionInterval`) is the interval in which the collector will collect metrics from the configured receivers. For most optimal default experience, we recommend using the 30 second interval set by the chart. However, if you'd prefer to collect metrics more (or less) often, you can adjust the interval by changing the `global.collectionInterval` value in the `values.yaml` file. The minimal recommended global interval is `15s`. If you wish to use default value for *each* component set internally by the collector, you can remove the collection interval parameter from presets completely.

Beware that using lower interval will result in more metric data points being sent to the backend, thus resulting in more costs. Note that the choise of the interval also has an effect on behavior of rate functions, for more see [here](https://www.robustperception.io/what-range-should-i-use-with-rate/).

### About batch sizing

[Batch processor](https://github.com/open-telemetry/opentelemetry-collector/tree/main/processor/batchprocessor) ensures that the telemetry being sent to Coralogix backend is batched into bigger requests, ensuring lower networking overhead and better performance. The batching processor is enabled by default and we strongly recommend to use it. By default, the `otel-integration` chart uses the following recommended settings for batch processors in all collectors:

```yaml
    batch:
      send_batch_size: 1024
      send_batch_max_size: 2048
      timeout: "1s"
```

These settings imposes a hard limit of 2048 units (spans, metrics, logs) on the batch size, ensuring a balance between the recommended size of the batches and networking overhead.

You may adjust these settings according to your needs, but when configuring the batch processor by yourself, it is important to be mindful of the size limites imposed by the Coraloigx endpoints (currently **max. 10 MB** after decompression - see [documentation](https://coralogix.com/docs/opentelemetry/#limits--quotas)).

More information on how to configure the batch processor can be found [here](https://github.com/open-telemetry/opentelemetry-collector/tree/main/processor/batchprocessor#batch-processor).

### About span metrics

The collector provides a possibility to synthesize R.E.D (Request, Error, Duration) metrics based on the incoming span data. This can be useful to obtain extra metrics about the operations you have instrumented for tracing. For more information, please refer to the [OpenTelemetry Collector documentation](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/connector/spanmetricsconnector/README.md).

This feature is disabled by default and can be enabled by setting the `spanmetrics.enabled` value to `true` in the `values.yaml` file.

Beware that enabling the feature will result in creation of additional metrics. Depending on how you instrument your applications, this can result in a significant increase in the number of metrics. This is especially true for cases where the span name includes specific values, such as user IDs or UUIDs. Such instrumentation practice is [strongly discouraged](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/trace/api.md#span).

In such cases, we recommend to either correct your instrumentation or to use the `spanMetrics.spanNameReplacePattern` parameter, to replace the problematic values with a generic placeholder. For example, if your span name corresponds to template `user-1234`, you can use the following pattern to replace the user ID with a generic placeholder. See the following configuration:

```yaml
spanNameReplacePattern: 
- regex: "user-[0-9]+"
  replacement: "user-{id}"
```

This will result in your spans having generalized name `user-{id}`.

#### SpanMetrics Database Monitoring

Once you enable the Span Metrics preset, the dbMetrics configuration will automatically be enabled. The DbMetrics option generates RED (Request, Errors, Duration) metrics for database spans. For example, query `db_calls_total` to view generated request metrics.

This is needed to enable the [Database Monitoring](https://coralogix.com/docs/user-guides/apm/features/database-monitoring/) feature inside Coralogix APM.

This is how you can disable the dbMetrics option:

```
presets:
    spanMetrics:
      enabled: true
      dbMetrics:
        enabled: false
```

Note: DbMetrics only works with OpenTelemetry SDKs that support OpenTelemetry Semantic conventions v1.26.0. If you are using older versions, you might need to transform some attributes, such as:

```
db.sql.table => db.collection.name
db.mongodb.collection => db.collection.name
db.cosmosdb.container => db.collection.name
db.cassandra.table => db.collection.name
```

To do that, you can add the following configuration:

```
    spanMetrics:
      enabled: false
      dbMetrics:
        enabled: true
        transformStatements:
        - set(attributes["db.namespace"], attributes["db.name"]) where attributes["db.namespace"] == nil
        - set(attributes["db.namespace"], attributes["server.address"]) where attributes["db.namespace"] == nil
        - set(attributes["db.namespace"], attributes["network.peer.name"]) where attributes["db.namespace"] == nil
        - set(attributes["db.namespace"], attributes["net.peer.name"]) where attributes["db.namespace"] == nil
        - set(attributes["db.namespace"], attributes["db.system"]) where attributes["db.namespace"] == nil
        - set(attributes["db.operation.name"], attributes["db.operation"]) where attributes["db.operation.name"] == nil
        - set(attributes["db.collection.name"], attributes["db.sql.table"]) where attributes["db.collection.name"] == nil
        - set(attributes["db.collection.name"], attributes["db.cassandra.table"]) where attributes["db.collection.name"] == nil
        - set(attributes["db.collection.name"], attributes["db.mongodb.collection"]) where attributes["db.collection.name"] == nil
        - set(attributes["db.collection.name"], attributes["db.redis.database_index"]) where attributes["db.collection.name"] == nil
        - set(attributes["db.collection.name"], attributes["db.elasticsearch.path_parts.index"]) where attributes["db.collection.name"] == nil
        - set(attributes["db.collection.name"], attributes["db.cosmosdb.container"]) where attributes["db.collection.name"] == nil
        - set(attributes["db.collection.name"], attributes["aws_dynamodb.table_names"]) where attributes["db.collection.name"] == nil
```

#### Span metrics with different buckets per application

If you want to use Span Metrics connector with different buckets per application you need to use `spanMetricsMulti` preset. For example:

```yaml
  presets:
    spanMetricsMulti:
      enabled: false
      defaultHistogramBuckets: [1ms, 4ms, 10ms, 20ms, 50ms, 100ms, 200ms, 500ms, 1s, 2s, 5s]
      configs:
        - selector: route() where attributes["service.name"] == "one"
          histogramBuckets: [1s, 2s]
        - selector: route() where attributes["service.name"] == "two"
          histogramBuckets: [5s, 10s]
```

For selector you need to write a [OTTL](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/pkg/ottl/README.md) statement, more information is available in [routing connector docs](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/connector/routingconnector).

### Multi-line log configuration

This helm chart supports multi-line configurations for different namespace, pod, and/or container names. The following example configuration applies a specific firstEntryRegex for a container which is part of a x Pod in y namespace:

```yaml
  presets:
    logsCollection:
      enabled: true
      multilineConfigs:
        - namespaceName:
            value: kube-system
          podName:
            value: app-a.*
            useRegex: true
          containerName:
            value: http
          firstEntryRegex: ^[^\s].*
          combineWith: ""
        - namespaceName:
            value: kube-system
          podName:
            value: app-b.*
            useRegex: true
          containerName:
            value: http
          firstEntryRegex: ^[^\s].*
          combineWith: ""
        - namespaceName:
            value: default
          firstEntryRegex: ^[^\s].*
          combineWith: ""

```

This feature uses [filelog receiver's](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/receiver/filelogreceiver/README.md) [router](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/pkg/stanza/docs/operators/router.md) and [recombine](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/pkg/stanza/docs/operators/recombine.md) operators.

Alternatively, you can add a recombine filter at the end of log collection operators using `extraFilelogOperators` field. The following example adds a single recombine operator for all Kubernetes logs:

```yaml
  presets:
    logsCollection:
      enabled: true
      extraFilelogOperators:
        - type: recombine
          combine_field: body
          source_identifier: attributes["log.file.path"]
          is_first_entry: body matches "^(YOUR-LOGS-REGEX)"
```

### Integrating Kube State Metrics

You can configure otel-integration to collect Kube State Metrics metrics. Using Kube State Metrics is useful when missing metrics or labels in the Kubernetes Cluster Receiver. Kube State Metrics collects Kubernetes cluster-level metrics that are crucial for monitoring resource states, like pods, deployments, and HorizontalPodAutoscalers (HPAs). To integrate with Kube State Metrics, create a file called `values-ksm.yaml`, and there configure the metrics and labels that you wish to collect:

```yaml
metricAllowlist:
  - kube_horizontalpodautoscaler_labels
  - kube_horizontalpodautoscaler_spec_max_replicas
  - kube_horizontalpodautoscaler_status_current_replicas
  - kube_pod_info
  - kube_pod_labels
  - kube_pod_container_status_waiting
  - kube_pod_container_status_waiting_reason
metricLabelsAllowlist:
  - pods=[app,environment]
  - horizontalpodautoscalers=[app,environment]
```

Then install Kube State Metrics:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-state-metrics prometheus-community/kube-state-metrics --values values-ksm.yaml
```

This command adds the Prometheus community's Helm repository and installs Kube State Metrics using the values you've configured.

Next, configure opentelemetry-cluster-collector to scrape Kube State Metrics via Prometheus receiver.

```bash
helm upgrade --install otel-coralogix-integration coralogix-charts-virtual/otel-integration . --values values-cluster-ksm.yaml
```

Once the installation is complete, verify that the Kube State Metrics metrics are being scraped and ingested inside Coralogix.

# Troubleshooting

## Metrics

You can enhance metrics telemetry level using `level` field. The following is a list of all possible values and their explanations.

- "none" indicates that no telemetry data should be collected;
- "basic" is the recommended and covers the basics of the service telemetry.
- "normal" adds some other indicators on top of basic.
- "detailed" adds dimensions and views to the previous levels.

For example:

```yaml
service:
  telemetry:
    metrics:
      level: detailed
      address: ":8888"
```

This adds more metrics around exporter latency and various processors metrics.

## Traces

OpenTelemetry Collector has an ability to send it's own traces using OTLP exporter. You can send the traces to OTLP server running on the same OpenTelemetry Collector, so it goes through configured pipelines. For example:

```
service:
  telemetry:
    traces:
      processors:
        batch:
          exporter:
            otlp:
              protocol: grpc/protobuf
              endpoint: ${env:MY_POD_IP}:4317
```

# Filtering and reducing metrics cost.

otel-integration has a couple of ways you can reduce the metric cost. One simple way is to enable `reduceResourceAttributes` preset, which removes the following list of resource attributes that are typically not used:
- container.id
- k8s.pod.uid
- k8s.replicaset.uid
- k8s.daemonset.uid
- k8s.deployment.uid
- k8s.statefulset.uid
- k8s.cronjob.uid
- k8s.job.uid
- k8s.hpa.uid
- k8s.namespace.uid
- k8s.node.uid
- net.host.name
- net.host.port

Kubernetes resource attributes are typically coming from [Kubernetes Attributes Processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/processor/k8sattributesprocessor/README.md) and [Kubernetes Cluster receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8sclusterreceiver).

While `net.host.name` and `net.host.port` is coming from Prometheus receiver, instead of using these attributes you can use the `service.instance.id` attribute, which has a combination of host and port.

## Custom filtering

Alternatively, you can also use include / exclude filters to collect only metrics about needed objects. For example, the following configuration allows you to exclude `kube-*` and `default` namespace Kubernetes metrics. This filtering is available on many [mdatagen](https://github.com/open-telemetry/opentelemetry-collector/tree/main/cmd/mdatagen) based receiver.

For example:

```yaml
receivers:
  k8s_cluster:
    collection_interval: 10s
    allocatable_types_to_report: [cpu, memory]
    resource_attributes:
      k8s.namespace.name:
        metrics_exclude:
          - regexp: kube-.*
          - strict: default
```

## Dropping data using processors

Alternatively you can use [OpenTelemetry Transformation Language](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/pkg/ottl/README.md) with [filter](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/filterprocessor) processor to filter out unneeded data. The following example drops metrics named `my.metric` and any metrics with resource where attribute `my_label` equals `abc123`:

```yaml
processors:
  filter/ottl:
    error_mode: ignore
    metrics:
      metric:
          - name == "my.metric" 
          - resource.attributes["my_label"] == "abc123"
```

# Performance of the Collector

## Picking the right tracing SDK span processor

OpenTelemetry tracing SDK supports two strategies to create an application traces, a “SimpleSpanProcessor” and a “BatchSpanProcessor.” While the SimpleSpanProcessor submits a span every time a span is finished, the BatchSpanProcessor processes spans in batches, and buffers them until a flush event occurs. Flush events can occur when the buffer is full or when a timeout is reached.

Picking the right tracing SDK span processor can have an impact on the performance of the collector. We switched our SDK span processor from SimpleSpanProcessor to BatchSpanProcessor and noticed a massive performance improvement in the collector:

| Span Processor      | Agent Memory Usage | Agent CPU Usage | Latency Samples |
|---------------------|--------------------|-----------------|-----------------|
| SimpleSpanProcessor | 3.7 GB             | 0.5             | >1m40s          |
| BatchSpanProcessor  | 600 MB             | 0.02            | >1s <10s        |

In addition, it improved the buffer performance of the collector, when we used the SimpleSpanProcessor, the buffer queues were getting full very quickly, and after switching to the BatchSpanProcessor, it stopped becoming full all the time, therefore stopped dropping data.

#### Example

```python
import BatchSpanProcessor from "@opentelemetry/sdk-trace-base";
tracerProvider.addSpanProcessor(new BatchSpanProcessor(exporter));
```

# Infrastructure Monitoring

## Log Collection

Default installation collects Kubernetes logs.

## Kubernetes Events

Kubernetes events provide a rich source of information. These objects can be used to monitor your application and cluster state, respond to failures, and perform diagnostics. The events are generated when the cluster’s resources — such as pods, deployments, or nodes — change state.

Whenever something happens inside your cluster, it produces an events object that provides visibility into your cluster. However, Kubernetes events don’t persist throughout your cluster life cycle, as there’s no mechanism for retention. They’re short-lived and only available for one hour after the event is generated.

With that in mind we're configuring an OpenTelemetry receiver to collect Kubernetes events and ship them to the `kube-events` subSystem so that you can leverage all the other features such as dashboard and alerting using Kubernetes events as the source of information.

On the OpenTelemetry config, you will find a new pipeline named `logs/kube-events`, which is used to collect, process, and export the Kubernetes events to Coralogix.

### Cleaning the data

By default, there's a transform processor named `transform/kube-events` which is removing some unneeded fields, but feel free to override this and add back some fields or even remove fields that are not needed at all on your specific use case.

### Filtering Events

On large-scale environments, you may have hundreds or even millions of events per hour, and maybe you don't need all of them, with that in mind you can leverage another OpenTelemetry processor to filter the events and don't send it to Coralogix, below you can find a config sample.

```yaml
processors:
      filter/kube-events:
        logs:
          log_record:
            - 'IsMatch(body["reason"], "(BackoffLimitExceeded|FailedScheduling|Unhealthy)") == true'
```

This configuration is filtering out any event that has the field `reason` with one of those values `BackoffLimitExceeded|FailedScheduling|Unhealthy`, for more information about the `filter` processor feel free to check the official documentation [here](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/filterprocessor).

## Dashboards

Under the `dashboard` directory, there are:

- Host Metrics Dashboard
- Kubernetes Pod Dashboard
- Span Metrics Dashboard
- Otel-Agent Grafana dashboard

# Integration presets

The `otel-integration` chart also provides support to integrate with different applications. The following integration presets are available.

## MySQL

The MySQL preset is able to collect metrics and extra logs (slow query log, general query log) from your MySQL instances. **Extra logs collection is available only when running the `otel-integration` as CRD with the OpenTelemetry Operator.**

### Prerequisites

This preset supports MySQL version 8.0

Collecting most metrics requires the ability of the database user to execute `SHOW GLOBAL STATUS`.

### Configuration for metrics collection

The metrics collection has to be enabled by setting the `metrics.enabled` to `true`.

Each MySQL instance is configured in the `metrics.instances` section. You can configure multiple instances, if you have more than one instance you'd like to monitor.

Required instance settings:
- `username`: The username of the database user that will be used to collect metrics.
- `password`: The password of the database user that will be used to collect metrics. We strongly recommend to provide this via a Kuberetes secret as an environment variable, e.g `MYSQL_PASSWORD`, which should be provided in the `extraEnv` section of the chart. This parameter should be passed in format `${env:MYSQL_PASSWORD}` in order for the collector to be able to read it.

Optional instance settings:
- `port`: The port of the MySQL instance. Defaults to `3306`. Unless you use non-standard port, there is no need to set this parameter.
- `labelSelectors`: A list of label selectors to select the pods that run the MySQL instances. If you wish to monitor mutiple instance, the selectors will determine which pods belong to a given instance.

### Configuration for extra logs collection

The extra logs collection has to be enabled by setting the `extraLogs.enabled` to `true`. Note that the extra logs have to enabled on your MySQL instance (please refer to [relevant documentation](https://dev.mysql.com/doc/refman/8.0/en/server-logs.html)). Please also note that extra logs collection is only available when running `otel-integration` with OpenTelemetry Operator.

**PLEASE NOTE:** In order for the collection to take effect, you need to annotate your MySQL instance(s) pod templates with the following:

```bash
kubectl patch sts <YOUR_MYSQL_INSTANCE_NAME> -p '{"spec": {"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"coralogix-opentelemetry-collector-mysql-logs-sidecar"}}}} }'
```

Required settings:
- `volumeMountName`: specifies the name of the volume mount. It should correspond to the volume name of the MySQL data volume.
- `mountPath`: specifies the path at which to mount the volume. This should correspond the mount path of your MySQL data volume. Provide this parameter without trailing slash.

Optional settings:
- `logFilesPath`: specifies which directory to watch for log files. This will typically be the MySQL data directory, such as `/var/lib/mysql`. If not specified, the value of `mountPath` will be used.
- `logFilesExtension`: specifies which file extensions to watch for. Defaults to `.log`.

### Common issues

- Metrics collection is failing with error `"Error 1227 (42000): Access denied; you need (at least one of) the PROCESS privilege(s) for this operation"`
  - This error indicates that the database user you provided does not have the required privileges to collect metrics. Provide the `PROCESS` privilege to the user, e.g. by running query `GRANT PROCESS ON *.* TO 'user'@'%'`

### Example preset configuration for single instance

```yaml
  mysql:
    metrics:
      enabled: true 
      instances:
      - username: "otel-coralogix-collector"
        password: ${env:MYSQL_PASSWORD}
        collectionInterval: 30s
    extraLogs:
      enabled: true
      volumeMountName: "data"
      mountPath: "/var/log/mysql"
```

### Example preset configuration for multiple instance

```yaml
  mysql:
    metrics:
      enabled: true 
      instances:
      - username: "otel-coralogix-collector"
        password: ${env:MYSQL_PASSWORD_INSTANCE_A}
        labelSelectors:
          app.kubernetes.io/name: "mysql-a"
      - username: "otel-coralogix-collector"
        password: ${env:MYSQL_PASSWORD_INSTANCE_B}
        labelSelectors:
          app.kubernetes.io/name: "mysql-b"
    extraLogs:
      enabled: true
      volumeMountName: "data"
      mountPath: "/var/log/mysql"
```

# Dependencies

This chart uses [openetelemetry-collector](https://github.com/coralogix/opentelemetry-helm-charts/tree/main/charts/opentelemetry-collector) Helm chart.
