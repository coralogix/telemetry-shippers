FROM logstash:7.17.2

USER root


# CVE-2026-111943: Ubuntu 20.04 has no fixed ca-certificates; distrust the compromised eMudhra
# roots in the OS store and in the bundled JDK cacerts (used by the JRuby output plugin).
# DL3008: Pin apt packages.
# DL3009: Delete apt lists after installing packages.
# DL3015: Use --no-install-recommends.
# hadolint ignore=DL3008,DL3009,DL3015
RUN apt-get update \
    && apt-get install -y python ruby \
    && chown logstash:root /usr/share/logstash/config/logstash.yml \
    && sed -i -E 's#^mozilla/(emSign_ECC_Root_CA_-_G3|Comodo_AAA_Services_root)\.crt$#!&#' /etc/ca-certificates.conf \
    && update-ca-certificates --fresh \
    && for a in 'c=gb,st=greater manchester,l=salford,o=comodo ca limited,cn=aaa certificate services' \
                'c=in,ou=emsign pki,o=emudhra technologies limited,cn=emsign ecc root ca - g3'; do \
         /usr/share/logstash/jdk/bin/keytool -delete -cacerts -storepass changeit -alias "$a"; done

USER logstash
RUN logstash-plugin install logstash-output-coralogix \
    && logstash-plugin install logstash-filter-json_encode

EXPOSE 5044 9600
ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]
