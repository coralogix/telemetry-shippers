FROM coralogixrepo/coralogix-fluentd-multiarch:1.7.1
USER root
RUN gem install fluent-plugin-docker_metadata_filter
                
COPY fluent.conf /fluentd/etc/
COPY firelens.conf /fluentd/etc/
