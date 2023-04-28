# Changelog

## Fluentd-http

### v0.0.11 / 2023-03-13
* [CHANGE] Disable PodSecurityPolicy

### v0.0.3 / 2022-04-26

* [UPGRADE] Upgrade Fluentd version to v1.14.6
* [CHANGE] Set default logLevel to error
* [CHANGE] Set buffer overflow_action to 'throw_exception' instead of 'block'
* [CHANGE] Set flush_thread_count to 4 for parallelism of the outputs
  ([#48](https://github.com/coralogix/eng-integrations/pull/48))

### v0.0.2 / 2022-04-19

* [CHANGE] Enable Coralogix subsystem to be fetched from kuberentes metadata fields
  ([#41](https://github.com/coralogix/eng-integrations/pull/41))

## Fluent-Bit

### v0.1.0 / 2023-02-03

* [UPGRADE] Upgrade Fluent-bit version to 2.0.8
* [CHANGE] Enable by default the new storage metrics plugins which gives more information about fluent bit ingestion.

### v0.0.4 / 2023-01-23

* Updating fluent-bit to the 2.0.5 version

### v0.0.3 / 2022-05-19

* Updating the app version to 1.9.3 in the 'chart.yaml' file

### v0.0.2 / 2022-04-26

* [UPGRADE] Upgrade Fluent-Bit version to 1.9.3
* [CHANGE] Set Retry_Limit to False [no limit] to keep retrying send the logs and not lose any data
  ([#48](https://github.com/coralogix/eng-integrations/pull/48))
