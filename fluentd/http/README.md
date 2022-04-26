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
    value: namespace_name
  - name: SUB_SYSTEM
    value: container_name
  - name: APP_NAME_SYSTEMD
    value: systemd
  - name: SUB_SYSTEM_SYSTEMD
    value: kubelet.service
  - name: ENDPOINT
    value: <[put_your_coralogix_endpoint_here](https://github.com/coralogix/eng-integrations/blob/master/fluentd/http/README.md#coralogix-endpoints)>
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

## Coralogix Endpoints

| Region  | Logs Endpoint
|---------|------------------------------------------|
| EU      | `api.coralogix.com`                      |
| EU2     | `api.eu2.coralogix.com`                  |
| US      | `api.coralogix.us`                       |
| SG      | `api.coralogixsg.com`                    |
| EUROPE1 | `tracing-ingress.coralogix.com:9443`     |
| EUROPE2 | `tracing-ingress.eu2.coralogix.com:9443` |
| IN      | `api.app.coralogix.in`                   |

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

## Coralogix Fluentd Buffer Alert
Fluentd uses memory to store buffer chunks, once its buffer is full, it starts throwing exceptions in its logs,
and it means there is a bottleneck, the Fluentd cant tail new logs.
Therefore we recommend creating an alert in Coralogix, that will trigger while Fluentd starts throwing buffer exceptions,
Run the following command in order to create a new alert in Coralogix: 
** `Alerts, Rules and Tags API Key` needs to be inserted in the command
** Notifications emails and integrations need to be updated 

```
curl -X POST https://api.eu2.coralogix.com/api/v1/external/alerts -H "Authorization: bearer <Alerts, Rules and Tags API Key>" -H "Content-Type: application/json" --data-binary '{
        "name": "Fluentd Buffer Full",
        "severity": "critical",
        "is_active": true,
        "log_filter": {
                "text": "BufferOverflow",
                "category": null,
                "filter_type": "text",
                "severity": ["error", "critical"],
                "application_name": ["default"],
                "subsystem_name": ["fluentd"],
                "computer_name": null,
                "class_name": null,
                "ip_address": null,
                "method_name": null
        },
        "condition": {
                "condition_type": "more_than",
                "threshold": 3,
                "timeframe": "5MIN",
                "group_by": "host"
        },
        "notifications": {
                "emails": ["security@mycompany.com", "mgmt@mycompany.com"],
                "integrations": ["myintegration"]
        },
        "notify_every": 60,
        "description": "Fluentd buffer is full, destination capacity is insufficient for your traffic.",
        "active_when": {
                "timeframes": [{
                        "days_of_week": [
                                0,
                                1,
                                2,
                                3,
                                4,
                                5,
                                6
                        ],
                        "activity_ends": "00:00:00",
                        "activity_starts": "00:00:01"
                }]
        }
}'
```