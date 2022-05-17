ARG IMAGE_VERSION=v1.14.6-debian-forward-1.0
FROM fluent/fluentd-kubernetes-daemonset:${IMAGE_VERSION}

# Image description labels
LABEL Description="Multi-Arch FluentD image for Coralogix integration" \
      Vendor="Coralogix Inc." \
      Version="1.0.0" \
      Maintainer="Coralogix Inc. <info@coralogix.com>"

# Change user
USER root

# Installing dependencies and plugins
RUN gem install fluent-plugin-coralogix \
      fluent-plugin-parser-cri \
      fluent-plugin-kubernetes_metadata_filter \
      fluent-plugin-sampling-filter \
      fluent-plugin-concat \
      fluent-plugin-rewrite-tag-filter \
      fluent-plugin-detect-exceptions

RUN gem install fluent-plugin-prometheus -v 2.0.3
RUN gem update fluent-plugin-prometheus