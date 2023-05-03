# THIS PLUGIN IS NO LONGER MAINTAINED - USE THE HTTP PLUGIN - [Fluentbit HTTP](https://github.com/coralogix/telemetry-shippers/blob/master/logs/fluent-bit/k8s-helm/http/README.md)

# Fluent-Bit-Coralogix Chart

#### Please read the [main README](https://github.com/coralogix/telemetry-shippers/blob/master/README.md) before following this chart installation.

Fluent-Bit is a lightweight data shipper, that we are using as a logs shipper to our platform.
Here you can find instructions on how to install the Fluent-Bit shipper, together with the Coralogix output plugin to ship the logs to the Coralogix platform.
The default values we provide can be overriden according to your needs, the default values can be showed by running:

```
helm show values coralogix-charts-virtual/fluent-bit-coralogix
```

## Installation with dynamic app_name and sub_system

By default we set the `app_name` and `subsystem` dynamically.

Dynamic `App_Name` and `Sub_System` means that the value is coming from any desired field from your logs' structure.

For example:

```bash
helm upgrade fluent-bit-coralogix coralogix-charts-virtual/fluent-bit-coralogix \
  --install \
  --namespace=<your-namespace> \
  --create-namespace \
  --set "fluent-bit.app_name=<app_name>" \ # Dynamic label, such as: kubernetes.namespace_name
  --set "fluent-bit.sub_system=<sub_system>" \ # Dynamic label, such as: kubernetes.containers_name
  --set "fluent-bit.endpoint=ingress.eu2.coralogix.com" # Can be changed
```

## Installation with static app_name and sub_system

Static `App_Name` and `Sub_System` means using hardcoded values, like 'production', 'test'.
For setting static values for app_name / subsystem, see the following example:s

```yaml
---
#override-fluentbit-coralogix.yaml
fluent-bit:
  config:
    outputs: |-
      [OUTPUT]
          Name          coralogix
          Endpoint      ingress.eu2.coralogix.com
          Match         kube.*
          Private_Key   ${PRIVATE_KEY}
          App_Name      <static_app_name>
          Sub_Name      <static_sub_system_name>

      @INCLUDE output-systemd.conf
```

```bash
helm upgrade fluent-bit-coralogix coralogix-charts-virtual/fluent-bit-coralogix \
  --install \
  --namespace=<your-namespace> \
  -f override-fluentbit-coralogix.yaml
```

## Coralogix Endpoints

| Region | Logs Endpoint               |
|--------|-----------------------------|
| EU     | `ingress.coralogix.com`     |
| EU2    | `ingress.eu2.coralogix.com` |
| US     | `ingress.coralogix.us`      |
| SG     | `ingress.coralogixsg.com`   |
| IN     | `ingress.coralogix.in`      |

**NOTE**
We suggest using dynamic app_name and sub_system, since it's more agile than using static values.

## Dashboard

Under the `dashboard` directory, there is a Fluent-Bit Grafana dashboard that Coralogix supplies.
Please see [the dashboard README](https://github.com/coralogix/telemetry-shippers/blob/master/logs/fluent-bit/dashboard/README.md) for installation instructions.
