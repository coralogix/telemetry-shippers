FROM logstash:7.16.2

USER root

RUN yum update && yum install -y python ruby logstash

RUN chown logstash:root /usr/share/logstash/config/logstash.yml

USER logstash
RUN logstash-plugin install logstash-output-coralogix
RUN logstash-plugin install logstash-filter-json_encode

EXPOSE 5044 9600
ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]
