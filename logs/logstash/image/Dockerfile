FROM logstash:7.17.2

USER root



# hadolint ignore=DL3008,DL3009,DL3015,DL3027
RUN apt update && apt install -y python ruby

# hadolint ignore=DL3059
RUN chown logstash:root /usr/share/logstash/config/logstash.yml

USER logstash
RUN logstash-plugin install logstash-output-coralogix
# hadolint ignore=DL3059
RUN logstash-plugin install logstash-filter-json_encode

EXPOSE 5044 9600
ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]
