# Changelog

## OpenTelemtry-Collector

### v0.0.3 / 2022-09-06

* [UPRADE] Upgrading chart version from 0.25.0 to 0.30.0
* [UPRADE] Upgrading app version from 0.57.2 to 0.59.0

### v0.0.2 / 2022-08-24
 
* [FIX] Disable logs and metrics pipeline by default 
* [FIX] Installation command had a wrong configuratin and chart name 
* [CHANGE] Update the Coralogix private key secret name to match the logs charts required secret name ['coralogix-otel-privatekey' --> 'integrations-privatekey'] 
  ([#80](https://github.com/coralogix/eng-integrations/pull/80))

