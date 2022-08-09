Coralogix Fluentd AWS ECS Image:
This folder contains the docker file for the image Coralogix promotes for ECS usecases.
fluent.conf - is the default conf, for EC2 usecases.
firelens.conf - a configuration ment specificly for Fargate usecases, must be enabled by configuring via Json.

Image base:
The image is based on our Coralogix fluentd multiarch image: coralogixrepo/coralogix-fluentd-multiarch:latest

supported plugins:
docker metadata- https://github.com/fabric8io/fluent-plugin-docker_metadata_filter