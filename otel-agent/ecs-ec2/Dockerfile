FROM otel/opentelemetry-collector-contrib:0.76.3 as src

FROM alpine:latest

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x entrypoint.sh

COPY --from=src /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=src otelcol-contrib /otelcontribcol
EXPOSE 4318 4317 55679

ENTRYPOINT [ "/entrypoint.sh" ]
