ARG COLLECTOR_VERSION=0.135.0
ARG SUPERVISOR_VERSION=0.135.0

FROM alpine:3.22 AS certs
RUN apk --update add ca-certificates
RUN mkdir -p /etc/otelcol-contrib/supervisor-data

FROM ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-opampsupervisor:${SUPERVISOR_VERSION} AS supervisor

FROM ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:${COLLECTOR_VERSION} AS collector

# Uncomment the line below to generate a more helpful debug container
# FROM alpine:3.22

USER 10001:10001

# Uncomment the line below to generate a more helpful debug container
# COPY --from=collector /otelcol-contrib /otelcol-contrib
COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=supervisor --chmod=755 /usr/local/bin/opampsupervisor /opampsupervisor
COPY --from=certs --chmod=744 --chown=10001:10001 /etc/otelcol-contrib/supervisor-data /etc/otelcol-contrib/supervisor-data

ENTRYPOINT ["/opampsupervisor"]
EXPOSE 4317 4318 55678 55679
