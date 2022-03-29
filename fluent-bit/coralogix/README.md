# Fluent-Bit-Coralogix Chart
#### Please read the [main README](https://github.com/coralogix/eng-integrations/blob/master/README.md) before following this chart installation.

Fluent-Bit is a lightweight data shipper, that we are using as a logs shipper to our platform.
Here you can find instructions on how to install the Fluent-Bit shipper, together with the Coralogix output plugin to ship the logs to the Coralogix platform.
The default values we provide can be overriden according to your needs, the default values can be showed by running:
```
helm show values coralogix-charts-virtual/fluent-bit-coralogix
```

## Installation
The following environment variables can be overriden via the 'set' flag in the upgrade command:
* app_name
* sub_system
* endpoint
* logLevel

for example:
```
helm upgrade fluent-bit-coralogix coralogix-charts-virtual/fluent-bit-coralogix --install --namespace=<your-namespace> --create-namespace --set "fluent-bit.logLevel=<level>"
--set "fluent-bit.app_name=<app_name>" --set "fluent-bit.sub_system=<sub_system>" --set "fluent-bit.endpoint=<Coralogix-endpoint>"
```

## Update APP_NAME and SUB_SYSTEM
The default configuration for the `APP_NAME` is namespace, which means the apps will be separated by namespaces.
The deafult configuration for the `SUB_SYSTEM` is container_name, which means the the sub_system will be separated by container names.
If you want to change the value of one of these, to a static value - meaning it's hardcoded like 'production', 'test', you will need instead of adding '--set' to the install command, 
to create the following override file [which exists under the `examples` directory], in order to change the `OUTPUTS` section. 

If the value you set is hardcoded in app_name, then you need to write:
```
App_Name      ${APP_NAME}
```
[instead of App_Name_Key]

If the value you set is hardcoded in sub_name, then you need to write:
```
Sub_Name      ${SUB_SYSTEM}
```
[Instead of Sub_Name_Key]

or both if needed.

* If you change the values to another dynamic value, for example 'container_name', 'pod_name', 'namespace_name', 
then the `set` command is enough, and no need to edit the config in the 'override.yaml'.

* If you also need to update the endpoint, and anyways creating the 'override.yaml' file, then you can add the updated endpoint value inside like shown in the example,
instead of using 'set' in the installation command.

```yaml
---
#override.yaml
fluent-bit: 
  config:
    outputs: |-
      [OUTPUT]
          Name          coralogix
          Endpoint      ${ENDPOINT}
          Match         kube.*
          Private_Key   ${PRIVATE_KEY}
          App_Name      ${APP_NAME}
          Sub_Name      ${SUB_SYSTEM}

      @INCLUDE output-systemd.conf
```

## Configuration Override: 
The fluent-bit configuration can be overriden seperately per each section (input, filter, output), there is no need to copy the whole config section to your values.yaml file in order to override one section. For example, in order to update some values in the input section, only the `inputs` section under the `config` needs to appear in the override file. 
``` 
---
#override.yaml
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
#override.yaml
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
--set "fluent-bit.app_name=<app_name>" --set "fluent-bit.sub_system=<sub_system>" --set "fluent-bit.endpoint=<Coralogix-endpoint>" -f "override.yaml"
```

* For override.yaml examples, please see: [fluent-bit override examples](https://github.com/coralogix/eng-integrations/blob/master/fluent-bit/examples)

## Dashboard
Under the `dashboard` directory, there is a Fluent-Bit Grafana dashboard that Coralogix supplies.
In order to import the dashboard into Grafana, firstly copy the json file content.
Afterwards go to Grafana press the `Create` tab, then press `import`, and paste the copied json file.

## Dependencies
By default this chart installs additional dependent chart:
(https://github.com/fluent/helm-charts/tree/main/charts/fluent-bit)