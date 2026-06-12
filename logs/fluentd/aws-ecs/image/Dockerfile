FROM coralogixrepo/coralogix-fluentd-multiarch:v1.18.0-4
# hadolint ignore=DL3002
USER root
# hadolint ignore=DL3028
RUN gem install fluent-plugin-docker_metadata_filter
# hadolint ignore=DL3028,DL3059
RUN gem install fluent-plugin-script
# hadolint ignore=DL3008,DL3009,DL3015,DL3027,DL3059
RUN apt update && apt install -y curl
COPY fargate.rb /fluentd/etc/
COPY fluent.conf /fluentd/etc/
COPY firelens.conf /fluentd/etc/
