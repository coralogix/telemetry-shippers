# Fluentd-HTTP Chart

#### Please read the [main README](https://github.com/coralogix/telemetry-shippers/blob/master/README.md) before following this chart installation.

Fluentd is a flexible data shipper with many available plugins and capabilities, that we are using as a logs shipper to our platform.
Here you can find instructions on how to install the Fluentd shipper, together with the http output plugin to ship the logs to the Coralogix platform.
The default values can be showed by running:

```
helm show values coralogix-charts-virtual/fluentd-http
```

## Installation

In order to update the environment variables, please create a new yaml file and include all the envs inside, including the overrides, for example:

```yaml
---
#override.yaml:
fluentd:
  env:
  - name: APP_NAME
    value: namespace_name
  - name: SUB_SYSTEM
    value: container_name
  - name: APP_NAME_SYSTEMD
    value: systemd
  - name: SUB_SYSTEM_SYSTEMD
    value: kubelet.service
  - name: ENDPOINT
    value: <put_your_coralogix_endpoint_here>
  - name: "FLUENTD_CONF"
    value: "../../etc/fluent/fluent.conf"
  - name: LOG_LEVEL
    value: error
  - name: K8S_NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName
```

```bash
helm upgrade fluentd-http coralogix-charts-virtual/fluentd-http \
  --install --namespace=<your-namespace> \
  --create-namespace \
  -f override.yaml
```

## Kubernetes Version 1.25+

PodSecurityPolicy is deprecated in Kubernetes v1.21+, and unavailable in Kubernetes v1.25+.
Therefore, the PodSecurityPolicy is disabled in this chart since version 0.0.11.

## Coralogix Endpoints

| Region | Logs Endpoint               |
|--------|-----------------------------|
| EU     | `ingress.coralogix.com`     |
| EU2    | `ingress.eu2.coralogix.com` |
| US     | `ingress.coralogix.us`      |
| SG     | `ingress.coralogixsg.com`   |
| IN     | `ingress.coralogix.in`      |

## Disable Systemd Logs

In order to disable the systemd logs, please create a new yaml file or edit your existing override.yaml that includes the environment varibales, and comment out the fluentd-system-conf line:

```yaml
---
#override.yaml
fluentd:
  configMapConfigs:
    - fluentd-prometheus-conf
    # - fluentd-systemd-conf
```

## Dashboard

Under the `dashboard` directory, there is a Fluentd Grafana dashboard that Coralogix supplies.
In order to import the dashboard into Grafana, firstly copy the json file content.
Afterwards go to Grafana press the `Create` tab, then press `import`, and paste the copied json file.

## Dependencies

By default this chart installs additional dependent chart:
(https://github.com/fluent/helm-charts/tree/main/charts/fluentd)

## Coralogix Fluentd Buffer Alert

In order to create an alert on Fluentd buffer in Coralogix, please see [coralogix-alert doc](https://github.com/coralogix/telemetry-shippers/blob/master/logs/fluentd/docs/coralogix-alerts.md)


## Log Logs: containerd / CRI partial logs

If your application is generating logs longer than 16k you should notice that docker dirver is splitting the log in multiple messages.
To fix this we can use concat to fix this.

First lets make sure that in the override file, that you use to deploy the helm, has logtag as one of the regex group keys, just like this.

```yaml
<pattern>
  format /^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>[^ ]*) (?<message>.*)$/
  time_format %Y-%m-%dT%H:%M:%S.%L%z
  keep_time_key true
</pattern>
```
If that is not the case please replace the existing one with this one.

Then next to the source we will add the following filter that will concat the logs:

```yaml
<filter raw.containers.**>
  @type concat
  key message
  use_partial_cri_logtag true
  partial_cri_logtag_key logtag
  partial_cri_stream_key stream
</filter>
```
