# Changelog

## OpenTelemtry-Agent

### v0.0.23 / 2023-03-29

* [CHORE] Update OpenTelemetry Collector to v0.74.0
* [FIX] Change DNS policy to ClusterFirstWithHostNet,

### v0.0.22 / 2023-02-24

* [CHORE] Update OpenTelemetry Collector to v0.72.0

### v0.0.21 / 2023-02-16

* [FEATURE] Add podName and nodeName to the k8sattributes processor

### v0.0.20 / 2023-02-13

* [UPRADE] Upgrading chart version from 0.47.0 to 0.48.1

### v0.0.19 / 2023-01-26

* [CHORE] Update OpenTelemetry Collector to v0.70.0

### v0.0.18 / 2022-12-21

* [FIX] Set node_from_env_var filter for k8sattributes, reducing memory and cpu usage for those using k8sattributes

### v0.0.17 / 2022-12-20

* [FEATURE] Add pprof extension

### v0.0.16 / 2022-12-15

* [FEATURE] Add checkpoints for Kubernetes logs
* [FIX] Host metrics processor exclude various pseudo filesystems
* [CHORE] Update OpenTelemetry Collector to v0.67.0

### v0.0.15 / 2022-12-12

* [FEATURE] Add support for thrift_binary protocol in Jaeger receiver

### v0.0.14 / 2022-12-11

* [BUGFIX] Add all of the relevant metrics to be suported in hostmetrics   

### v0.0.13 / 2022-12-08

* [FEATURE] Configure hostmetrics filesystem metrics

### v0.0.12 / 2022-11-30

* [FEATURE] Add zpages extension
* [BUGFIX] Increase Coralogix exporter timeout 5s -> 30s

### v0.0.11 / 2022-11-28

* [UPGRADE] Upgrading chart version from 0.39.0 to 0.40.2
* [UPGRADE] Upgrading app version from v0.64.0 to v0.66.0

### v0.0.10 / 2022-11-21

* [FEATURE] Add self monitoring 

### v0.0.9 / 2022-11-10

* [FEATURE] Support OpenTelemetry native agent
* [FIX] Example override file attribute

### v0.0.8 / 2022-09-19

* [FEATURE] Add a Grafana dashboard for OpenTelemetry agent

### v0.0.7 / 2022-09-18

* [BUGFIX] Set the jaeger receiver thrift_binary protocol default endpoint

### v0.0.6 / 2022-09-18

* [FEATURE] Add binary protocol to Jaeger reciever

### v0.0.5 / 2022-09-15

* [CHANGE] Enable hostNetwork

### v0.0.4 / 2022-09-08

* [FEATURE] Add support for metrics using the Coralogix exporter
* [FIX] Change serviceMonitor to podMonitor since serviceMonitor is not supported for daemonset mode

### v0.0.3 / 2022-09-06

* [UPRADE] Upgrading chart version from 0.25.0 to 0.30.0
* [UPRADE] Upgrading app version from 0.57.2 to 0.59.0

### v0.0.2 / 2022-08-24
 
* [FIX] Disable logs and metrics pipeline by default 
* [FIX] Installation command had a wrong configuratin and chart name 
* [CHANGE] Update the Coralogix private key secret name to match the logs charts required secret name ['coralogix-otel-privatekey' --> 'integrations-privatekey'] 
  ([#80](https://github.com/coralogix/eng-integrations/pull/80))

