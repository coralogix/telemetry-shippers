# Upgrade guidelines

These upgrade guidelines only contain instructions for version upgrades which require manual modifications on the user's side.
If the version you want to upgrade to is not listed here, then there is nothing to do for you.
Just upgrade and enjoy.

When upgrading to new collector version please check OpenTelemetry collector release notes here:
- https://github.com/open-telemetry/opentelemetry-collector/releases
- https://github.com/open-telemetry/opentelemetry-collector-contrib/releases

## v0.0.195 to v0.0.196

**Important Note for Tail-Sampling Configuration:**

If you are using tail-sampling configuration, you must change the `coralogixExporter` preset pipelines to `none` to avoid conflicts with the tail-sampling setup:

```yaml
opentelemetry-agent:
  presets:
    coralogixExporter:
      enabled: true
      privateKey: ${env:CORALOGIX_PRIVATE_KEY}
      pipelines: ["none"]
```

See the [tail-sampling-values.yaml](https://github.com/coralogix/telemetry-shippers/blob/master/otel-integration/k8s-helm/tail-sampling-values.yaml#L9-L21) for a complete example.

## v0.0.177 to v0.0.184

We have migrated from static configurations provided in config to a more flexible presets-based approach. This change makes values.yaml more configurable by users, allowing you to enable or disable specific features that you don't use.

For example, previously we configured `jaegerReceiver` in values.yaml:

```
opentelemetry-agent:
  config:
    receivers:
      jaeger:
        protocols:
          grpc:
            endpoint: ${env:MY_POD_IP}:14250
          thrift_http:
            endpoint: ${env:MY_POD_IP}:14268
          thrift_compact:
            endpoint: ${env:MY_POD_IP}:6831
          thrift_binary:
            endpoint: ${env:MY_POD_IP}:6832
    service:
      pipelines:
        traces:
          exporters:
            - coralogix
          ...
          receivers:
            - ..
            - jaeger
  ports:
    ...
    jaeger-binary:
      enabled: true
      containerPort: 6832
      servicePort: 6832
      hostPort: 6832
      protocol: TCP
```

Now it becomes:

```
opentelemetry-agent:
  presets:
    jaegerReceiver:
      enabled: true
```

This gives you more control over your OpenTelemetry configuration and helps you only enable the features you need.

New presets added:

| Preset                | Description                                                                                                                                                                                                                                                                   |
|-----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| collectorMetrics      | Configures the collector to collect its own metrics using Prometheus receiver. Adds the prometheus receiver to the metrics pipeline with a scrape config targeting the collector's metrics endpoint. Also adds a transform processor to clean up metric names and attributes. |
| jaegerReceiver        | Configures the collector to receive Jaeger data in all supported protocols. Adds the jaeger receiver to the traces pipeline with all protocols configured. Opens ports: 14250 (gRPC), 14268 (HTTP), 6831 (Thrift Compact), 6832 (Thrift Binary).                              |
| zipkinReceiver        | Configures the collector to receive Zipkin data. Adds the zipkin receiver to the traces pipeline. Opens port 9411.                                                                                                                                                            |
| otlpReceiver          | Configures the collector to receive OTLP data. Adds the OTLP receiver to the traces, metrics, and logs pipelines. Opens ports: 4317 (gRPC), 4318 (HTTP).                                                                                                                      |
| statsdReceiver        | Configures the collector to receive StatsD metrics. Adds the statsd receiver to the metrics pipeline. Opens port 8125.                                                                                                                                                        |
| zpages                | Configures the collector to expose zPages for debugging. Opens port 55679.                                                                                                                                                                                                    |
| pprof                 | Configures the collector to expose pprof for profiling.                                                                                                                                                                                                                       |
| batch                 | Configuration for the batch processor. Adds the batch processor to the logs, metrics, and traces pipelines.                                                                                                                                                                   |
| coralogixExporter     | Configures the collector to export data to Coralogix.                                                                                                                                                                                                                         |
| resourceDetection     | Configures resource detection processors to add system, environment and cloud information. Also configures volumes and volume mounts for the collector.                                                                                                                       |
| semconv               | Applies semantic convention transformations.                                                                                                                                                                                                                                  |
| k8sResourceAttributes | Configures Internal Collector's resource attributes for the collector.                                                                                                                                                                                                        |

## 0.0.89 to 0.0.90

If you are providing your own configuration that relies on implicit conversion of types, this behavior is now deprecated and will not be supported in one of the future release (might cause your collectors to fail during start). Please update your configuration accordingly - to see which type casting behaviors are affected see the list [here](https://github.com/open-telemetry/opentelemetry-collector/issues/9532).

For example, if you previously had a configuration like this:

```yaml
 service:
      telemetry:
        resource:
          - service.instance.id:
          - service.name:
```

You should change it to this instead:

```yaml
      telemetry:
        resource:
          service.instance.id: ""
          service.name: ""
```

## 0.0.84 to 0.0.85

If you are providing your own environemnt variables that are being expanded in the collector configuration, be sure to use the recommended syntax with the `env:` prefix (for example: `${env:ENV_VAR}` or `${ENV_VAR}` instead of just `$ENV_VAR`). For more information see [here](https://github.com/open-telemetry/opentelemetry-collector-contrib/releases/tag/v0.104.0). The old way of setting environment variables will be removed in the near future.

## 0.0.43 to 0.0.44

Because 0.0.44 sets GOMEMLIMIT automatically for pods, it is recommended to remove memoryballast extension if you manually configured the pipeline. Removing memoryballast extension should reduce memory footprint for your pods. See https://github.com/open-telemetry/opentelemetry-helm-charts/issues/891 for more information/

Additionally, logging exporter has been deprecated, we recommend to switch to debug exporter instead. See https://github.com/open-telemetry/opentelemetry-collector/blob/main/exporter/debugexporter/README.md for more information.

## 0.0.36 to 0.0.37

From version `0.0.37`, the deprecated `spanmetricsprocessor` has been removed and replaced by the `spanmetricsconnector` and is **disabled** by default. If you depend on the span metrics, please enable the `spanmetricsconnector` by setting the following in the `presets` section of your configuration:

```yaml
opentelemetry-agent:
  presets:
    spanMetrics:
      enabled: true
```

Please beware there are also breaking changes with regards to metric naming and labels. Please see the [this section of documentation](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/connector/spanmetricsconnector/README.md#span-to-metrics-processor-to-span-to-metrics-connector) for more information.

## 0.0.32 to 0.0.33

Opentelemetry Integration v0.33 has removed Kube State Metrics deployment, as the needed resource attributes and metrics are now part of OpenTelemetry Kubernetes Cluster Receiver.

We removed `metricstransform/kube-extra-metrics` processor, as it was transforming `kube-state-metrics` metrics. And added two processors `metricstransform/k8s-dashboard` and `transform/k8s-dashboard` which transforms OTEL format into the format which Coralogix Kubernetes Dashboard uses.

If you manually configured the opentelemetry-cluster-collectors metrics pipeline, you will need to add `metricstransform/k8s-dashboard` and `transform/k8s-dashboard` processors to your pipeline.

Previously, we had cluster collector's metrics pipeline that looked like this:

```
opentelemetry-cluster-collector:
   ...
        metrics:
          exporters:
            - coralogix
          processors:
            - k8sattributes
            - metricstransform/kube-extra-metrics
            - resourcedetection/env
            - resourcedetection/region
            - memory_limiter
            - batch

```

Now, the new cluster collector's metrics pipeline should look like this:

```
opentelemetry-cluster-collector:
   ...
        metrics:
          exporters:
            - coralogix
          processors:
            - k8sattributes
            - metricstransform/k8s-dashboard
            - transform/k8s-dashboard
            - resourcedetection/env
            - resourcedetection/region
            - memory_limiter
            - batch

```

If you didn't configure the metrics pipeline for opentelemetry-cluster-collector, this is not a breaking change.
