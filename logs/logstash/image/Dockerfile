FROM logstash:7.17.2

USER root


# DL3008: Pin apt packages.
# DL3009: Delete apt lists after installing packages.
# DL3015: Use --no-install-recommends.
# hadolint ignore=DL3008,DL3009,DL3015
RUN apt-get update \
    && apt-get install -y python ruby \
    && chown logstash:root /usr/share/logstash/config/logstash.yml

USER logstash
RUN logstash-plugin install logstash-output-coralogix \
    && logstash-plugin install logstash-filter-json_encode

EXPOSE 5044 9600
ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]
