ARG IMAGE_VERSION=v1.14.0-debian-1.0
FROM fluent/fluentd:${IMAGE_VERSION}

# Image description labels
LABEL Description="Multi-Arch FluentD image for Standalone Coralogix integration" \
      Vendor="Coralogix Inc." \
      Version="1.0.0" \
      Maintainer="Coralogix Inc. <info@coralogix.com>"

# Change user
USER root

# Installing dependencies and plugins
RUN gem install fluent-plugin-coralogix \
      fluent-plugin-prometheus \
      fluent-plugin-parser-cri \
      fluent-plugin-sampling-filter \
      fluent-plugin-concat \
      fluent-plugin-rewrite-tag-filter \
      fluent-plugin-detect-exceptions \
      fluent-plugin-redisstore

