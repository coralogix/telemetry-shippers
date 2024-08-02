# Upgrade guidelines

These upgrade guidelines only contain instructions for version upgrades which require manual modifications on the user's side.
If the version you want to upgrade to is not listed here, then there is nothing to do for you.
Just upgrade and enjoy.

When upgrading to new collector version please check OpenTelemetry collector release notes here:
- https://github.com/open-telemetry/opentelemetry-collector/releases
- https://github.com/open-telemetry/opentelemetry-collector-contrib/releases

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

If you are providing your own environemnt variables that are being expanded in the collector configuration, be sure to use the recommended syntax with the `env:` prefix (for example: `${env:ENV_VAR}` instead of just `${ENV_VAR}`). For more information see [here](https://github.com/open-telemetry/opentelemetry-collector-contrib/releases/tag/v0.104.0). The old way of setting environment variables will be removed in the near future.

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
