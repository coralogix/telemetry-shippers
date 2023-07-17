### K8s

This Infrastructure collector provides:

- [Coralogix Exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/coralogixexporter) - Coralogix exporter is preconfigured to enrich data using Kubernetes Attributes, which allows quick correlation of telemetry signals using consistent ApplicationName and SubsytemName fields.
- [Cluster Metrics Receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/k8sclusterreceiver) - The Kubernetes Cluster receiver collects cluster-level metrics from the Kubernetes API server. Alternative to Kube State Metrics project.
- [Integrations presets](#integration-presets) - This chart provides support to integrate with various applications running on your cluster to monitor them out of the box.

### OpenTelemetry Operator (for CRD users)

If you wish to use this Helm chart as an `OpenTelemetryCollector` CRD, you will need to have the OpenTelemetry Operator installed in your cluster. Please refer to the [OpenTelemetry Operator documentation](https://github.com/open-telemetry/opentelemetry-operator/blob/main/README.md) for full details.

We recommend to install the operator with the help of the community Helm charts from the [OpenTelemetry Helm Charts](https://github.com/open-telemetry/opentelemetry-helm-charts/tree/main/charts/opentelemetry-operator) repository.

### Required

- **Secret Key**

Follow the [private key docs](https://coralogix.com/docs/private-key/) tutorial to obtain your secret key tutorial to obtain your secret key.

OpenTelemetry Infrastructure Collector require a `secret` called `coralogix-keys` with the relevant `private key` under a secret key called `PRIVATE_KEY`, inside the `same namespace` that the chart is installed in.

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

## Installation

First make sure to add our Helm charts repository to the local repos list with the following command:

```bash
helm repo add coralogix-charts-virtual https://cgx.jfrog.io/artifactory/coralogix-charts-virtual
```

In order to get the updated Helm charts from the added repository, please run:

```bash
helm repo update
```

Install the charts:

```bash
helm upgrade --install otel-infrastructure-collector coralogix-charts-virtual/otel-infrastructure-collector \
  -f values.yaml
```

### Generating OpenTelemetryCollector CRD for OpenTelemetry Operator users

If you wish to deploy the `otel-agent` using the OpenTelemetry Operator, you can generate an `OpenTelemetryCollector` CRD. You might want to do this if you'd like to take advantage of some advanced features provided by the operator, such as automatic collector upgrade or CRD-defined auto-instrumentation.

For full details on how to install and use the operator, please refer to the [OpenTelemetry Operator documentation](https://github.com/open-telemetry/opentelemetry-operator/blob/main/README.md).

First make sure to add our Helm charts repository to the local repos list with the following command:

```bash
helm repo add coralogix-charts-virtual https://cgx.jfrog.io/artifactory/coralogix-charts-virtual
```

In order to get the updated Helm charts from the added repository, please run:

```bash
helm repo update
```

Install the chart with the CRD `values.yaml` file:

```bash
helm upgrade --install otel-coralogix-agent coralogix-charts-virtual/opentelemetry-coralogix \
  -f values-crd.yaml
```

# Infrastructure Monitoring

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
## Cluster Receiver

## Alerts

# Integration presets

The `otel-infrastructure-collector` chart also provides support to integrate with different applications. The following integration presets are available.

## MySQL

The MySQL preset is able to collect metrics and extra logs (slow query log, general query log) from your MySQL instances. **Extra logs collection is available only when running the `otel-infrastructure-collector` as CRD with the OpenTelemetry Operator.**

### Prerequisites

This preset supports MySQL version 8.0

Collecting most metrics requires the ability of the database user to execute `SHOW GLOBAL STATUS`.

### Configuration for metrics collection

The metrics collection has to be enabled by setting the `metrics.enabled` to `true`.

Each MySQL instance is configured in the `metrics.instances` section. You can configure multiple instances, if you have more than one instance you'd like to monitor.

Required instance settings:
- `username`: The username of the database user that will be used to collect metrics.
- `password`: The password of the database user that will be used to collect metrics. We strongly recommend to provide this via a  Kuberetes secret as an environment variable, e.g `MYSQL_PASSWORD`, which should be provided in the `extraEnv` section of the chart. This parameter should be passed in format `${env:MYSQL_PASSWORD}` in order for the collector to be able to read it.

Optional instance settings:
- `port`: The port of the MySQL instance. Defaults to `3306`. Unless you use non-standard port, there is no need to set this parameter.
- `labelSelectors`: A list of label selectors to select the pods that run the MySQL instances. If you wish to monitor mutiple instance, the selectors will determine which pods belong to a given instance.

### Configuration for extra logs collection

The extra logs collection has to be enabled by setting the `extraLogs.enabled` to `true`. Note that the extra logs have to enabled on your MySQL instance (please refer to https://dev.mysql.com/doc/refman/8.0/en/server-logs.html). Please also note that extra logs collection is only available when running `otel-infrastructure-collector` with OpenTelemetry Operator.

**PLEASE NOTE:** In order for the collection to take effect, you need to annotate your MySQL instance(s) pod templates with the following:

```bash
kubectl patch sts <YOUR_MYSQL_INSTANCE_NAME> -p '{"spec": {"template":{"metadata":{"annotations":{"sidecar.opentelemetry.io/inject":"otel-infrastructure-collector-mysql-logs-sidecar"}}}} }'
```

Required settings:
- `volumeMountName`: specifies the name of the volume mount. It should correspond to the volume name of the MySQL data volume.
- `mountPath`: specifies the path at which to mount the volume. This should correspond the mount path of your MySQL data volume. Provide this parameter without trailing slash.

Optional settings:
- `logFilesPath`: specifies which directory to watch for log files. This will typically be the MySQL data directory,
 such as `/var/lib/mysql`. If not specified, the value of `mountPath` will be used.
- `logFilesExtension`: specifies which file extensions to watch for. Defaults to `.log`.

### Common issues

- Metrics collection is failing with error `"Error 1227 (42000): Access denied; you need (at least one of) the PROCESS privilege(s) for this operation"`
  - This error indicates that the database user you provided does not have the required privileges to collect metrics. Provide the `PROCESS` privilege to the user, e.g. by running query 
  `GRANT PROCESS ON *.* TO 'user'@'%'`

### Example preset configuration for single instance

```yaml
  mysql:
    metrics:
      enabled: true 
      instances:
      - username: "otel-coralogix-collector"
        password: ${env:MYSQL_PASSWORD}
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

This chart uses [openetelemetry-collector](https://github.com/open-telemetry/opentelemetry-helm-charts/tree/main/charts/opentelemetry-collector) helm chart.
