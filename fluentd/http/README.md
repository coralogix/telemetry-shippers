# Fluentd-HTTP Chart
#### Please read the [main README](https://github.com/coralogix/eng-integrations/blob/master/README.md) before following this chart installation.

Fluentd is a flexible data shipper with many available plugins and capabalities, that we are using as a logs shipper to our platform.
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
    value: <app_name>
  - name: SUB_SYSTEM
    value: <sub_system>
  - name: APP_NAME_SYSTEMD
    value: systemd
  - name: SUB_SYSTEM_SYSTEMD
    value: kubelet.service
  - name: ENDPOINT
    value: <coralogix_endpoint>
  - name: "FLUENTD_CONF"
    value: "../../etc/fluent/fluent.conf"
  - name: LOG_LEVEL
    value: <level>
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

* For override.yaml examples, please see: [fluentd override examples](https://github.com/coralogix/eng-integrations/blob/master/fluentd/examples)

## Dashboard
Under the `dashboard` directory, there is a Fluentd Grafana dashboard that Coralogix supplies.
In order to import the dashboard into Grafana, firstly copy the json file content.
Afterwards go to Grafana press the `Create` tab, then press `import`, and paste the copied json file.

## Dependencies
By default this chart installs additional dependent chart:
(https://github.com/fluent/helm-charts/tree/main/charts/fluentd)
