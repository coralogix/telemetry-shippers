FROM coralogixrepo/coralogix-fluentd-multiarch:v1.18.0-4
USER root
RUN gem install fluent-plugin-docker_metadata_filter
RUN gem install fluent-plugin-script
RUN apt update && apt install -y curl
COPY fargate.rb /fluentd/etc/
COPY fluent.conf /fluentd/etc/
COPY firelens.conf /fluentd/etc/
