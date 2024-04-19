# Changelog

## Prometheus-Agent

### v0.0.18 / 2024-04-19
* [FIX] Add README example for externalLabels key

### v0.0.18 / 2024-02-07
* [FEATURE] Adding Prometheus Agent volumes and volumes mount
* [FEATURE] Adding Prometheus Agent image registry

### v0.0.17 / 2024-02-07
* [FEATURE] Adding Pod Metadata to Prometheus Agent

### v0.0.16 / 2024-02-07
* [FEATURE] Adding Image Pull Secrets to Prometheus Agent

### v0.0.15 / 2023-07-10
* [UPGRADE] Upgrade prometheus version to 2.45.0

### v0.0.14 / 2023-05-22
* [FIX] Remove non required objects from Prometheus object

### v0.0.13 / 2023-05-22
* [FIX] Provide default values for prometheus.monitoring.coreos.com since null values are not allowed

### v0.0.12 / 2023-02-20
* [UPGRADE] Upgrade prometheus version to 2.43.0-stringlabels

### v0.0.10 / 2023-02-20
* [FIX] Prometheus Agent logs config

### v0.0.10 / 2023-02-20
* [FEATURE] Adding shard support

### v0.0.9 / 2023-02-20
* [FEATURE] Adding Prometheus Startup Probe Override

### v0.0.9 / 2023-02-20
* [FEATURE] Adding Prometheus Service

### v0.0.8 / 2023-02-20

* [FEATURE] Adding Self Monitor
* [FEATURE] Adding extra features to improve restarts

### v0.0.7 / 2023-02-20

* [UPGRADE] Upgrade prometheus version to 2.42.0

### v0.0.6 / 2023-02-15

* [FIX] Fix storage template to enable an empty storage field

### v0.0.5 / 2023-02-08

* [FIX] Update serviceAccount name template to use the fullName

### v0.0.4 / 2023-01-22

* [FEATURE] Add Prometheus image to the template so it can be overriden

### v0.0.3 / 2023-01-19

* [FEATURE] Add template support for external labels

### v0.0.2 / 2023-01-18

* [FIX] Add Storage to the template
