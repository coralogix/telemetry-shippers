# Changelog

## OpenTelemtry Agent for Windows

### v0.0.6 / 2023-10-04
* Use image version based on the `appVersion` parameter.
* Bump image collector image version to `0.83.0`.

### v0.0.5 / 2023-09-28
* Remove `k8s.container.name`,`k8s.job.name` and `k8s.node.name` from subsystem attribute list

### v0.0.4 / 2023-08-17
* Remove memory ballast extension due to extensive memory usage.

### v0.0.3 / 2023-05-23
* Use image from Coralogix Docker Hub instead of the test image.

### v0.0.2 / 2023-05-23
* Add Service for DaemonSet, since windows does not support hostnetworking
* Fix includeCollectorLogs=true breaks configuration.
* Add support for Deployment and StatefulSet options.

### v0.0.1 / 2023-05-19

* Initial support for `isWindows`
