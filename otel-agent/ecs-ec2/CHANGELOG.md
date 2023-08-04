# Changelog

## OpenTelemtry-Agent

### v0.0.31 / 2023-08-02
* Remove `ecsattributes` processor from telemetryshippers repo
* Updated default configurations in logging.yaml and config.yaml

### v0.0.30 / 2023-07-18
* [FIX] fixed issue with ecsattributes processor adding empty labels/attributes
* [UPGRADE] add feature to ecsattribute processor to record custom docker labels

### v0.0.29 / 2023-07-14
* [FIX] fixed issue with ecsattributes processor not initialising correctly

### v0.0.28 / 2023-07-05
* [UPGRADE] coralogixrepo/otel-coralogix-ecs-ec2 container version updated to 0.80.0
* [UPGRADE] added custom ecsattributes processor to the container
* [CHANGE] modified ecs-ec2 container to leverage custom distribution with ecsattributes processor

### v0.0.27 / 2023-05-24
* [CHORE] Updated default otel agent config.yaml for ecs to support the new domain key for the Coralogix exporter

### v0.0.26 / 2023-05-24
* [UPGRADE] coralogixrepo/otel-coralogix-ecs-ec2 container version updated to 0.78.0
