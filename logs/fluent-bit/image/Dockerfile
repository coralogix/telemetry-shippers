FROM fluent/fluent-bit:3.2.10
ARG TARGETARCH
# DL3048: Invalid label key.
# hadolint ignore=DL3048
LABEL Maintainer="Coralogix Inc. <info@coralogix.com>"
# DL3048: Invalid label key.
# hadolint ignore=DL3048
LABEL Description="Special Fluent-Bit image for Coralogix integration" Vendor="Coralogix Inc." Version="3.2.10"
COPY ./functions.lua /fluent-bit/etc/
CMD ["/fluent-bit/bin/fluent-bit", "-c", "/fluent-bit/etc/fluent-bit.yaml"]
