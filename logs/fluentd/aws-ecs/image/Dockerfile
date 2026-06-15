FROM coralogixrepo/coralogix-fluentd-multiarch:v1.18.0-4
# DL3002: Last USER should not be root.
# hadolint ignore=DL3002
USER root
# DL3028: Pin versions in gem install.
# DL3009: Delete apt lists after installing packages.
# DL3015: Use --no-install-recommends.
# hadolint ignore=DL3028,DL3009,DL3015
RUN gem install fluent-plugin-docker_metadata_filter \
    && gem install fluent-plugin-script \
    && apt-get update \
    && apt-get install -y curl=7.88.1-10+deb12u14
COPY fargate.rb /fluentd/etc/
COPY fluent.conf /fluentd/etc/
COPY firelens.conf /fluentd/etc/
