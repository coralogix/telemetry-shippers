# Fluent-Bit-HTTP Chart
#### Please read the [main README](https://github.com/coralogix/eng-integrations/blob/master/README.md) before following this chart installation.

Fluent-Bit is a lightweight data shipper, that we are using as a logs shipper to our platform.
Here you can find instructions on how to install the Fluent-Bit shipper, together with the http output plugin to ship the logs to the Coralogix platform.
The default values we provide can be overriden according to your needs, the default values can be showed by running:
```bash
helm show values coralogix-charts-virtual/fluent-bit-http
```
## Default installation
A simple installation with the default values only specifing the correct endpoint.
By default we set `applicationName` to the log namespace name in k8s and `subsystemName` to the log container name is k8s.

```bash
helm upgrade fluent-bit-http coralogix-charts-virtual/fluent-bit-http \
  --install \
  --namespace=<your-namespace> \
  --create-namespace \
  --set "fluent-bit.endpoint=api.eu2.coralogix.com" # Override according to your account's region. 
```

## Installation with dynamic app_name and sub_system
Dynamic metadata `app_name` and `sub_system` means that the values for applicationName and subsystemName is coming from any desired field from your logs' structure.

installation using cli only:

```bash
helm upgrade fluent-bit-http coralogix-charts-virtual/fluent-bit-http \
  --install \
  --namespace=<your-namespace> \
  --create-namespace \
  --set "dynamic_metadata.app_name=myfield.application" \ # Each log's app_name will be fetched from the fluentbit record's 'myfield.application' value.
  --set "dynamic_metadata.sub_system=kubernetes.container_name" \ # Each log's subsystem will be fetched from the fluentbit record's 'kubernetes.container_name' value.
  --set "fluent-bit.endpoint=api.eu2.coralogix.com" # Override according to your account's region. 
```

installation using a values file:

```yaml
---
# override-values.yaml:
dynamic_metadata:
  app_name: myfield.application
  sub_system: kubernetes.container_name
fluent-bit:
  endpoint: api.eu2.coralogix.com
```

```bash
helm upgrade fluent-bit-http coralogix-charts-virtual/fluent-bit-http \
  --install \
  --namespace=<your-namespace> \
  --create-namespace \
  -f override-values.yaml
```

## Installation with static app_name and sub_system
static metadata `app_name` and `sub_system` means using hard-coded values for applicationName and subsystemName

installation using cli only:

```bash
helm upgrade fluent-bit-http coralogix-charts-virtual/fluent-bit-http \
  --install \
  --namespace=<your-namespace> \
  --create-namespace \
  --set "static_metadata.app_name=MyApplication" \ # Each log's app_name will be 'MyApplication'.
  --set "static_metadata.sub_system=MySubsystem" \ # Each log's subsystem will be 'MySubsystem'.
  --set "fluent-bit.endpoint=api.eu2.coralogix.com" # Override according to your account's region. 
```

installation using a values file:

```yaml
---
# override-values.yaml:
static_metadata:
  app_name: MyApplication
  sub_system: MySubsystem
fluent-bit:
  endpoint: api.eu2.coralogix.com
```

```bash
helm upgrade fluent-bit-http coralogix-charts-virtual/fluent-bit-http \
  --install \
  --namespace=<your-namespace> \
  --create-namespace \
  -f override-values.yaml
```
Note: we can use both static and dynamic at the sametime, static values take precedence.
## Coralogix Endpoints

| Region  | Logs Endpoint
|---------|------------------------------------------|
| EU      | `api.coralogix.com`                      |
| EU2     | `api.eu2.coralogix.com`                  |
| US      | `api.coralogix.us`                       |
| SG      | `api.coralogixsg.com`                    |
| IN      | `api.app.coralogix.in`                   |

**NOTE**
We suggest using dynamic app_name and sub_system, since it's more agile than using static values.

## Dashboard
Under the `dashboard` directory, there is a Fluent-Bit Grafana dashboard that Coralogix supplies.
Please see [the dashboard README](https://github.com/coralogix/eng-integrations/blob/master/fluent-bit/dashboard) for installation instructions.
