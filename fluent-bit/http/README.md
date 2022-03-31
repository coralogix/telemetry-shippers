# Fluent-Bit-HTTP Chart
#### Please read the [main README](https://github.com/coralogix/eng-integrations/blob/master/README.md) before following this chart installation.

Fluent-Bit is a lightweight data shipper, that we are using as a logs shipper to our platform.
Here you can find instructions on how to install the Fluent-Bit shipper, together with the http output plugin to ship the logs to the Coralogix platform.
The default values we provide can be overriden according to your needs, the default values can be showed by running:
```bash
helm show values coralogix-charts-virtual/fluent-bit-http
```

## Installation with default/dynamic app_name and sub_system
Dynamic App_Name and Sub_System means taking the value from the running containers, so it can be 'namespace', 'pod_name', 'container_name'.
If you need to override the default values, but still use dynamic app_name and sub_name, please follow these installation instructions: 
The following environment variables can be overriden via the 'set' flag in the upgrade command:
* app_name
* sub_system
* endpoint
* logLevel

for example:
```bash
helm upgrade fluent-bit-http coralogix-charts-virtual/fluent-bit-http \
  --install \
  --namespace=<your-namespace> \
  --create-namespace \
  --set "fluent-bit.logLevel=<level>" \
  --set "fluent-bit.app_name=<app_name>" \
  --set "fluent-bit.sub_system=<sub_system>" \
  --set "fluent-bit.endpoint=<Coralogix-endpoint>"
```

## Installation with static app_name and sub_system

### We suggest using dynamic app_name and sub_system, since it's more agile than using statiic values.

Static App_Name and Sub_System means using hardcoded values, like 'production', 'test'. 
If you need to override the default values, and use hardcoded values, then you need to create the following 'override-fluentbit-http.yaml' file instead of using '--set'.

```yaml
---
#override-fluentbit-http.yaml
fluent-bit: 
  #endpoint: <Coralogix_endpoint> --> Only if different from the defaults
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
          Name            nest
          Match           kube.*
          Operation       lift
          Nested_under    kubernetes
          Add_prefix      kubernetes.

      [FILTER]
          Name    modify
          Match   kube.*
          Add     applicationName <hard_coded_app_name>
          Add     subsystemName <hard_coded_subsystem_name>  

      [FILTER]
          Name            nest
          Match           kube.*
          Operation       nest
          Wildcard        kubernetes.*
          Nest_under      kubernetes
          Remove_prefix   kubernetes.

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

** Please notice that under the `FILTER` section I changed the word `copy` to `add`. If you want to override only the ApplicationName or only the SubSytemName, 
change the `copy` to `add` only where you need, for example, if you want to keep the sub_system default value,
and override only the app_name, then you need to update only the first line:
```
Add     applicationName <hard_coded_app_name>
Copy    ${SUB_SYSTEM} subsystemName
```

## Configuration Override: 
The fluent-bit configuration can be overriden seperately per each section (input, filter, output), there is no need to copy the whole config section to your values.yaml file in order to override one section. For example, in order to update some values in the input section, only the `inputs` section under the `config` needs to appear in the override file. 
```yaml
---
#override-fluentbit-http.yaml
fluent-bit: 
  config:
    inputs: |-
      [INPUT]
          Name tail
          Path <your-logs-path>
          multiline.parser docker, cri
          Tag <your-tag>
          Refresh_Interval <interval>
          Skip_Long_Lines <on/off>
          Mem_Buf_Limit <the size in MB>

      @INCLUDE input-systemd.conf
```

Another example, in order to update some values related to the systemd log shipping conf, the following section needs to be edited:
```yaml
---
#override-fluentbit-http.yaml
fluent-bit:
  config:
    extraFiles:
      input-systemd.conf: |-
        [INPUT]
            Name systemd
            Tag <your-tag>
            Systemd_Filter _SYSTEMD_UNIT=kubelet.service
            Read_From_Tail On
            Mem_Buf_Limit 5MB
```

* For override-fluentbit-http.yaml examples, please see: [fluent-bit override examples](https://github.com/coralogix/eng-integrations/blob/master/fluent-bit/examples)

## Dashboard
Under the `dashboard` directory, there is a Fluent-Bit Grafana dashboard that Coralogix supplies.
In order to import the dashboard into Grafana, firstly copy the json file content.
Afterwards go to Grafana press the `Create` tab, then press `import`, and paste the copied json file.

## Dependencies
By default this chart installs additional dependent chart:
(https://github.com/fluent/helm-charts/tree/main/charts/fluent-bit)
