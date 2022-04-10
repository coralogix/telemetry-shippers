# Fluent-Bit-HTTP Chart
#### Please read the [main README](https://github.com/coralogix/eng-integrations/blob/master/README.md) before following this chart installation.

Fluent-Bit is a lightweight data shipper, that we are using as a logs shipper to our platform.
Here you can find instructions on how to install the Fluent-Bit shipper, together with the http output plugin to ship the logs to the Coralogix platform.
The default values we provide can be overriden according to your needs, the default values can be showed by running:
```bash
helm show values coralogix-charts-virtual/fluent-bit-http
```

## Installation with dynamic app_name and sub_system
By default we set the `app_name` and `subsystem` dynamically.  
Dynamic `App_Name` and `Sub_System` means that the value is coming from any desired field from your logs' structure.

For example:
```bash
helm upgrade fluent-bit-http coralogix-charts-virtual/fluent-bit-http \
  --install \
  --namespace=<your-namespace> \
  --create-namespace \
  --set "fluent-bit.app_name=kubernetes.namespace_name" \ # Each log's app_name will be fetched from the fluentbit record's 'kubernetes.namespace_name' value.
  --set "fluent-bit.sub_system=kubernetes.container_name" \ # Each log's subsystem will be fetched from the fluentbit record's 'kubernetes.container_name' value.
  --set "fluent-bit.endpoint=api.eu2.coralogix.com" # Override according to your account's region. 
```

## Installation with static app_name and sub_system
Static `App_Name` and `Sub_System` means using hardcoded values.
For setting static values for app_name / subsystem, see the following example:s

```yaml
---
#override-fluentbit-http.yaml - configuring both app_name and subsystem as static values
fluent-bit:  
  config:
    filters: |-
      [FILTER]
          Name kubernetes
          Match kube.*
          K8S-Logging.Parser On
          K8S-Logging.Exclude On
          Use_Kubelet On
          Annotations Off
          Labels On
          Buffer_Size 0
          Keep_Log Off
          Merge_Log_Key log_obj
          Merge_Log On

      [FILTER]
          Name    modify
          Match   kube.*
          Add     applicationName production # Each log will be under 'production' application name 
          Add     subsystemName infra-services # Each log will be under 'infra-services' subsystem  

      [FILTER]
          Name        nest
          Match       kube.*
          Operation   nest
          Wildcard    kubernetes
          Wildcard    log
          Wildcard    log_obj
          Wildcard    stream
          Wildcard    time
          Nest_under  json

      @INCLUDE filters-systemd.conf
```

```bash
helm upgrade fluent-bit-http coralogix-charts-virtual/fluent-bit-http \
  --install \
  --namespace=<your-namespace> \
  -f override-fluentbit-http.yaml
```

**NOTE**
We suggest using dynamic app_name and sub_system, since it's more agile than using static values.

## Dashboard
Under the `dashboard` directory, there is a Fluent-Bit Grafana dashboard that Coralogix supplies.
Please see [the dashboard README](https://github.com/coralogix/eng-integrations/blob/master/fluent-bit/dashboard) for installation instructions.
