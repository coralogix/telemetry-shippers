ARG IMAGE_VERSION=v1.14.0-debian-1.0
# hadolint ignore=DL3006
FROM fluent/fluentd:${IMAGE_VERSION}

# Image description labels
# hadolint ignore=DL3048
LABEL Description="Multi-Arch FluentD image for Standalone Coralogix integration" \
      Vendor="Coralogix Inc." \
      Version="1.0.0" \
      Maintainer="Coralogix Inc. <info@coralogix.com>"

# Change user
# hadolint ignore=DL3002
USER root

# Installing dependencies and plugins
# hadolint ignore=DL3028
RUN gem install fluent-plugin-coralogix \
      fluent-plugin-prometheus \
      fluent-plugin-parser-cri \
      fluent-plugin-sampling-filter \
      fluent-plugin-concat \
      fluent-plugin-rewrite-tag-filter \
      fluent-plugin-detect-exceptions \
      fluent-plugin-redis-store
