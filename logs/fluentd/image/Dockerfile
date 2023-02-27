ARG IMAGE_VERSION=v1.15.2-debian-forward-1.0
FROM fluent/fluentd-kubernetes-daemonset:${IMAGE_VERSION}

# Image description labels
LABEL Description="Multi-Arch FluentD image for Coralogix integration" \
      Vendor="Coralogix Inc." \
      Version="1.0.0" \
      Maintainer="Coralogix Inc. <info@coralogix.com>"

# Change user
USER root

# Installing dependencies and plugins
RUN gem install elasticsearch -v 7.13

RUN gem install fluent-plugin-coralogix \
      fluent-plugin-parser-cri \
      fluent-plugin-sampling-filter \
      fluent-plugin-concat \
      fluent-plugin-rewrite-tag-filter \
      fluent-plugin-detect-exceptions \
      fluent-plugin-elasticsearch


RUN gem install fluent-plugin-kubernetes_metadata_filter -v 2.11.1
RUN gem install fluent-plugin-prometheus -v 2.0.3
