# CVE-2026-111943: copy in a fixed ca-certificates bundle (drops the compromised eMudhra roots).
FROM prom/prometheus:v3.13.5 AS certs

FROM prom/prometheus:v2.37.1
COPY --from=certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY prometheus.yml /etc/prometheus/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
# DL3002: Last USER should not be root.
# hadolint ignore=DL3002
USER root
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT [ "entrypoint.sh" ]
CMD        [ "--config.file=/etc/prometheus/prometheus.yml", \
             "--storage.tsdb.path=/prometheus", \
             "--web.console.libraries=/usr/share/prometheus/console_libraries", \
             "--web.console.templates=/usr/share/prometheus/consoles" ]
