# Fluentd-Coralogix Chart
#### Please read the [main README](https://github.com/coralogix/eng-integrations/blob/master/README.md) before following this chart installation.

Fluentd is a flexible data shipper with many available plugins and capabalities, that we are using as a logs shipper to our platform.
Here you can find instructions on how to install the Fluentd shipper, together with the Coralogix output plugin to ship the logs to the Coralogix platform.
The default values can be showed by running:
```
helm show values coralogix-charts-virtual/fluentd-coralogix 
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
  - name: MAX_LOG_BUFFER_SIZE
    value: "12582912"
  - name: K8S_NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName
```

```bash
helm upgrade fluentd-coralogix coralogix-charts-virtual/fluentd-coralogix \
  --install --namespace=<your-namespace> \
  --create-namespace \
  -f override.yaml
```

## Coralogix Endpoints

| Region  | Logs Endpoint
|---------|------------------------------------------|
| EU      | `api.coralogix.com`                      |
| EU2     | `api.eu2.coralogix.com`                  |
| US      | `api.coralogix.us`                       |
| SG      | `api.coralogixsg.com`                    |
| IN      | `api.app.coralogix.in`                   |

## Disable Systemd Logs
In order to disable the systemd logs, please create a new yaml file or edit your existing override.yaml that includes the environment varibales, and comment out the fluentd-system-conf line:
```
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