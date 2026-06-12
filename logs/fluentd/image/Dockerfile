            ARG IMAGE_VERSION=v1.18.0-debian-forward-1.4
            # hadolint ignore=DL3006
            FROM fluent/fluentd-kubernetes-daemonset:${IMAGE_VERSION}

# Image description labels
# hadolint ignore=DL3048
LABEL Description="Multi-Arch FluentD image for Coralogix integration" \
      Vendor="Coralogix Inc." \
      Version="1.18.0-4" \
      Maintainer="Coralogix Inc. <info@coralogix.com>"

# Change user
# hadolint ignore=DL3002
USER root

# Installing dependencies and plugins
RUN gem install elasticsearch -v 8.11

# hadolint ignore=DL3028,DL3059
RUN gem install fluent-plugin-coralogix \
      fluent-plugin-parser-cri \
      fluent-plugin-sampling-filter \
      fluent-plugin-concat \
      fluent-plugin-rewrite-tag-filter \
      fluent-plugin-detect-exceptions \
      fluent-plugin-elasticsearch


# hadolint ignore=DL3059
RUN gem install fluent-plugin-kubernetes_metadata_filter -v 3.4.0
# hadolint ignore=DL3059
RUN gem install fluent-plugin-prometheus -v 2.1.0
