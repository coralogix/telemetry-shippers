FROM prom/prometheus:v2.37.1
COPY prometheus.yml /etc/prometheus/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
# hadolint ignore=DL3002
USER root
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT [ "entrypoint.sh" ]
CMD        [ "--config.file=/etc/prometheus/prometheus.yml", \
             "--storage.tsdb.path=/prometheus", \
             "--web.console.libraries=/usr/share/prometheus/console_libraries", \
             "--web.console.templates=/usr/share/prometheus/consoles" ]
