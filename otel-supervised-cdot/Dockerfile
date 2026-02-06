# Version args must be provided (e.g., via Makefile which reads CURRENT_*_VERSION)
ARG COLLECTOR_VERSION
ARG SUPERVISOR_VERSION

FROM alpine:3.22 AS certs
RUN apk --update add ca-certificates
RUN mkdir -p /etc/otelcol-contrib/supervisor-data

FROM ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-opampsupervisor:${SUPERVISOR_VERSION} AS supervisor

FROM coralogixrepo/coralogix-otel-collector:${COLLECTOR_VERSION}

USER 10001:10001

COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=supervisor --chmod=755 /usr/local/bin/opampsupervisor /opampsupervisor
COPY --from=certs --chmod=744 --chown=10001:10001 /etc/otelcol-contrib/supervisor-data /etc/otelcol-contrib/supervisor-data

ENTRYPOINT ["/opampsupervisor"]
EXPOSE 4317 4318 55678 55679
