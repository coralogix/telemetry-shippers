# OpenTelemetry Integration

The OpenTelemetry Integration consists of two main compoenents, that provide our users with full fledged integration for their Kubernetes cluster - the [OpenTelemetry Agent](#opentelemetry-agent) and [OpenTelemetry Infrastructure Collector](#opentelemetry-infrastructure-collector). Depending on your needs, you can deploy both components (default behavior) or decide to disable eihter one under the `opentelemetry-collector-agent` or `opentelemetry-collector-infrastucture` sections in the `values.yaml` file.

Content:
1. [Components](#components)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [How to use it](#how-to-use-it)
5. [Performance of the Collector](#performance-of-the-collector)
6. [Infrastructure Monitoring](#infrastructure-monitoring)

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
- [Span Metrics](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/spanmetricsprocessor) - Traces are converted to Requests, Duration and Error metrics using spanmetrics processor.
- [Zpages Extension](https://github.com/open-telemetry/opentelemetry-collector/tree/main/extension/zpagesextension) - You can investigate latency and error issues by navigating to Pod's localhost:55516 web server. Routes are desribed in [OpenTelemetry documentation](https://github.com/open-telemetry/opentelemetry-collector/tree/main/extension/zpagesextension#exposed-zpages-routes)

## OpenTelemetry Infrastructure Collector

This Infrastructure collector provides:

- [Coralogix Exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/coralogixexporter) - Coralogix exporter is preconfigured to enrich data using Kubernetes Attributes, which allows quick correlation of telemetry signals using consistent ApplicationName and SubsytemName fields.
- [Cluster Metrics Receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8sclusterreceiver) - The Kubernetes Cluster receiver collects cluster-level metrics from the Kubernetes API server.
- [Kubernetes Events Receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8seventsreceiver) - The Kubernetes Events receiver collects events from the Kubernetes API server. See [Kubernetes Events](#kubernetes-events) for more information.
- Kubernetes Extra Metrics - This preset enables collection of extra Kubernetes related metrics, such as node information, pod status or container I/O metrics. These metrics are collected in particular for the [Kubernetes Dashboard](#kubernetes-dashboard).

## Kubernetes Dashboard

This chart will also collect, out of the box, all the metrics necessary for [Coralogix Kubernetes Monitoring](https://coralogix.com/docs/apm-kubernetes/), which will allow you to monitor your Kubernetes cluster and applications. To do this, it is necessary to deploy the [Kube-state-metrics](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-state-metrics) component, which makes it possible to obtain some of these extra metrics.

**Please be aware** that certain metrics collected by for the dashboard have high cardinality, which means that the number of unique values for a given metric is high and might result in higher costs connected with metrics ingestion and storage. This is applies in particular to the pod related metrics `kube_pod_status_reason`, `kube_pod_status_phase` and `kube_pod_status_qos_class`.

If you do not require to collect these metrics, you can disable them by setting `global.extensions.kubernetesDashboard.enabled` to `false` in the `values.yaml` file.

# Prerequisites

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
helm upgrade --install otel-integration coralogix-charts-virtual/opentelemetry-coralogix \
  -f values.yaml
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

The following code creates a new environment variable (`NODE`) containing the node's IP address and then uses that IP in the `OTEL_EXPORTER_OTLP_ENDPOINT` environment variable.
This ensures that each instrumented pod will send data to the local OTEL collector on the node it is currently running on.

```yaml
env:
  - name: NODE
    valueFrom:
      fieldRef:
        fieldPath: status.hostIP
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "$(NODE):4317"
```

# Performance of the Collector

## Picking the right tracing SDK span processor

OpenTelemetry tracing SDK supports two strategies to create an application traces, a “SimpleSpanProcessor” and a “BatchSpanProcessor.”
While the SimpleSpanProcessor submits a span every time a span is finished, the BatchSpanProcessor processes spans in batches, and buffers them until a flush event occurs. Flush events can occur when the buffer is full or when a timeout is reached.

Picking the right tracing SDK span processor can have an impact on the performance of the collector.
We switched our SDK span processor from SimpleSpanProcessor to BatchSpanProcessor and noticed a massive performance improvement in the collector:

| Span Processor      | Agent Memory Usage | Agent CPU Usage | Latency Samples |
|---------------------|--------------------|-----------------|-----------------|
| SimpleSpanProcessor | 3.7 GB             | 0.5             | >1m40s          |
| BatchSpanProcessor  | 600 MB             | 0.02            | >1s <10s        |

In addition, it improved the buffer performance of the collector, when we used the SimpleSpanProcessor, the buffer queues were getting full very quickly,
and after switching to the BatchSpanProcessor, it stopped becoming full all the time, therefore stopped dropping data.

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

# Dependencies

This chart uses [openetelemetry-collector](https://github.com/coralogix/opentelemetry-helm-charts/tree/main/charts/opentelemetry-collector) help chart. Also this chart currently depends on the [`kube-state-metrics`](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-state-metrics) chart to collect extra Kubernetes metrics.
