# Changelog

## OpenTelemtry-Agent

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

