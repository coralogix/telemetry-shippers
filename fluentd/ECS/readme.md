Coralogix Fluentd AWS ECS Image:
This folder contains the docker file for the image Coralogix promotes for ECS usecases.
firelens.conf - is ment for ECS Fargate
fluent.conf - for EC2 usecases

Image base:
The image is based on our Coralogix fluentd multiarch image: coralogixrepo/coralogix-fluentd-multiarch:latest

supported plugins:
docker metadata- https://github.com/fabric8io/fluent-plugin-docker_metadata_filter
