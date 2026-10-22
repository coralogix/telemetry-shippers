# CVE-2026-111943: copy in Debian's fixed ca-certificates (drops the compromised eMudhra roots).
FROM debian:bookworm-slim AS certs
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates=20250419~deb12u2 \
    && rm -rf /var/lib/apt/lists/*

FROM fluent/fluent-bit:3.2.10
COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
ARG TARGETARCH
# DL3048: Invalid label key.
# hadolint ignore=DL3048
LABEL Maintainer="Coralogix Inc. <info@coralogix.com>"
# DL3048: Invalid label key.
# hadolint ignore=DL3048
LABEL Description="Special Fluent-Bit image for Coralogix integration" Vendor="Coralogix Inc." Version="3.2.10"
COPY ./functions.lua /fluent-bit/etc/
CMD ["/fluent-bit/bin/fluent-bit", "-c", "/fluent-bit/etc/fluent-bit.yaml"]
