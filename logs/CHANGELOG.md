# Changelog

## Fluentd

### v1.16.5 / 2024-04-25
* [UPGRADE] Upgrade Fluentd Helm chart dependency to 0.5.2

### v1.16.5 / 2024-04-24
* [UPGRADE] Upgrade Fluentd version to v1.16.5

### v1.16.3 / 2023-11-23

* [CHANGE] Update the coralogix API

### v1.16.3 / 2023-11-22

* [UPGRADE] Upgrade Fluentd version to v1.16.3
* [UPGRADE] Upgrade Fluentd Helm chart dependency to 0.5.0

### v1.16.2 / 2023-11-09

* [UPGRADE] Upgrade Fluentd version to v1.16.2

### v1.15.2 / 2023-06-20

* [DOWNGRADE] Restoring the image version to 0.0.7 in the Fluentd Helm (Coralogix Plugin) 'values.yaml' file

### v1.15.2 / 2023-06-16

* [UPGRADE] Upgrade Fluentd version to v1.15.2

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

## v3.0.4 / 2024-05-21

* [UPGRADE] Upgrade Fluentbit version to v3.0.4 for CVE-2024-4323
* [UPGRADE] Upgrade Fluentbit Helm chart dependency to 0.46.7 for CVE-2024-4323

### v3.0.2 / 2024-04-24

* [UPGRADE] Upgrade Fluentbit version to v3.0.2
* [UPGRADE] Upgrade Fluentbit Helm chart dependency to 0.46.2

### v2.2.0 / 2023-11-23

* [CHANGE] Update the coralogix API

### v2.2.0 / 2023-11-22

* [UPGRADE] Upgrade Fluentbit version to v2.2.0
* [UPGRADE] Upgrade Fluentbit Helm chart dependency to 0.40.0

### v2.1.4 / 2023-06-21

[CHANGE] Fixing SUB_SYSTEM_SYSTEMD value.

### v2.1.3 / 2023-06-21

* [UPGRADE] Upgrade Fluent-bit version to 2.1.3
* [UPGRADE] Upgrade upstream Fluent-Bit helm chart dependency version to 0.30.4
* [CHANGE] Updated version scheme to map to upstream version
* [FIX] Updated Helm documentation to ensure deployment to "monitoring" namespace
* [FIX] Updated kubernetes deployment luascript to avoid excessive errors in pod logs
* [FIX] Updated kubernetes daemonset to consume fluent-bit-env configmap

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
