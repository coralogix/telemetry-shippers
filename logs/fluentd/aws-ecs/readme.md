Coralogix Fluentd AWS ECS Image: This folder contains the docker file for the image Coralogix promotes for ECS usecases. fluent.conf - is the default conf, for EC2 usecases. firelens.conf - a configuration meant specificly for Fargate usecases, must be enabled by configuring via Json since it will use it's own config.
The configuration should be done in the Fluentd options in configuring via Json as such:
{
                    "config-file-type": "file",
                    "config-file-value": "/fluentd/etc/firelens-extra.conf"
                }

Image base: The image is based on our Coralogix fluentd multiarch image: coralogixrepo/coralogix-fluentd-multiarch:latest


If you need to create a HEALTHCHECK on the log_router:
Use the following Healthcheck command:

CMD-SHELL, curl -f http://localhost:24220/api/plugins.json || exit 1

supported plugins: docker metadata- https://github.com/fabric8io/fluent-plugin-docker_metadata_filter
