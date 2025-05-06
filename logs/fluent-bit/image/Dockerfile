FROM fluent/fluent-bit:3.2.10
ARG TARGETARCH
LABEL Maintainer="Coralogix Inc. <info@coralogix.com>"
LABEL Description="Special Fluent-Bit image for Coralogix integration" Vendor="Coralogix Inc." Version="3.2.10"
COPY ./functions.lua /fluent-bit/etc/
CMD ["/fluent-bit/bin/fluent-bit", "-c", "/fluent-bit/etc/fluent-bit.yaml"]
