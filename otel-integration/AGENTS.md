When asked to upgrade the opentelemetry-collector chart version used by the Coralogix OpenTelemetry Integration, follow the process in the file `../.cursor/rules/otel-integration-upgrade.mdc`.

## Deployment Options

### Coralogix OpenTelemetry Integration Chart

The main deployment option using our custom Helm chart that combines agent and cluster collector in a single installation.

### Vanilla OpenTelemetry Collector with Coralogix

For users preferring the upstream OpenTelemetry Collector Helm chart, we provide pre-configured values files in [`k8s-helm/opentelemetry-helm-values/`](./k8s-helm/opentelemetry-helm-values/) that enable direct use of the `open-telemetry/opentelemetry-collector` chart with Coralogix exporters configured for both agent (DaemonSet) and cluster collector (Deployment) modes.
