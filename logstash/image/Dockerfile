FROM logstash:7.17.2

USER root

RUN apt update && apt install -y python ruby logstash

RUN chown logstash:root /usr/share/logstash/config/logstash.yml

USER logstash
RUN logstash-plugin install logstash-output-coralogix
RUN logstash-plugin install logstash-filter-json_encode

EXPOSE 5044 9600
ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]
