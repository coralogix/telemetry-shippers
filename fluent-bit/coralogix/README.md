# Fluent-Bit-Coralogix Chart
#### Please read the [main README](https://github.com/coralogix/eng-integrations/blob/master/README.md) before following this chart installation.

Fluent-Bit is a lightweight data shipper, that we are using as a logs shipper to our platform.
Here you can find instructions on how to install the Fluent-Bit shipper, together with the Coralogix output plugin to ship the logs to the Coralogix platform.
The default values we provide can be overriden according to your needs, the default values can be showed by running:
```
helm show values coralogix-charts-virtual/fluent-bit-coralogix
```

## Installation with default/dynamic app_name and sub_system
Dynamic App_Name and Sub_System can be any Kubernetes accessible environment variable [namespace, container_name, etc...], 
or any other supplied environment variable that is coming from the running containers. please see (dynamic examples)[(https://kubernetes.io/docs/tasks/inject-data-application/environment-variable-expose-pod-information/)]
If you need to override the default values [which are dynamic labels], and use other dynamic app_name and sub_name, please follow these installation instructions: 
The following environment variables can be overriden via the 'set' flag in the upgrade command:
* app_name
* sub_system
* endpoint
* logLevel

for example:
```bash
helm upgrade fluent-bit-coralogix coralogix-charts-virtual/fluent-bit-coralogix \
  --install \
  --namespace=<your-namespace> \
  --create-namespace \
  --set "fluent-bit.logLevel=<level>" \
  --set "fluent-bit.app_name=<app_name>" \ # Dynamic label, such as: kubernetes.namespace_name
  --set "fluent-bit.sub_system=<sub_system>" \ # Dynamic label, such as: kubernetes.containers_name
  --set "fluent-bit.endpoint=<Coralogix-endpoint>"
```

## Installation with static app_name and sub_system

### We suggest using dynamic app_name and sub_system, since it's more agile than using static values.

Static App_Name and Sub_System means using hardcoded values, like 'production', 'test'. 
If you need to override the default values, and use hardcoded values, then you need to create the following 'override-fluentbit-coralogix.yaml' file instead of using '--set'.

```yaml
---
#override-fluentbit-coralogix.yaml
fluent-bit:
  config:
    outputs: |-
      [OUTPUT]
          Name          coralogix
          Endpoint      <Coralogix_endpoint>
          Match         kube.*
          Private_Key   ${PRIVATE_KEY}
          App_Name      <static_app_name>
          Sub_Name      <static_sub_system_name>

      @INCLUDE output-systemd.conf
```

## Configuration Override: 
The fluent-bit configuration can be overriden seperately per each section (input, filter, output), there is no need to copy the whole config section to your values.yaml file in order to override one section. For example, in order to update some values in the input section, only the `inputs` section under the `config` needs to appear in the override file. 
``` 
---
#override-fluentbit-coralogix.yaml
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
```
---
#override-fluentbit-coralogix.yaml
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

```
helm upgrade fluent-bit-coralogix coralogix-charts-virtual/fluent-bit-coralogix --install --namespace=<your-namespace> --create-namespace --set "fluent-bit.logLevel=<level>"
--set "fluent-bit.app_name=<app_name>" --set "fluent-bit.sub_system=<sub_system>" --set "fluent-bit.endpoint=<Coralogix-endpoint>" -f "override-fluentbit-coralogix.yaml"
```

* For override-fluentbit-coralogix.yaml examples, please see: [fluent-bit override examples](https://github.com/coralogix/eng-integrations/blob/master/fluent-bit/examples)

## Dashboard
Under the `dashboard` directory, there is a Fluent-Bit Grafana dashboard that Coralogix supplies.
In order to import the dashboard into Grafana, firstly copy the json file content.
Afterwards go to Grafana press the `Create` tab, then press `import`, and paste the copied json file.

## Dependencies
By default this chart installs additional dependent chart:
(https://github.com/fluent/helm-charts/tree/main/charts/fluent-bit)