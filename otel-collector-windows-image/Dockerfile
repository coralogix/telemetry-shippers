# escape=`
ARG WIN_BASE_IMAGE

FROM --platform=$BUILDPLATFORM curlimages/curl AS build
WORKDIR /src
RUN curl -Lo otelcol.tar.gz https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.85.0/otelcol-contrib_0.85.0_windows_amd64.tar.gz
RUN tar -xzvf otelcol.tar.gz

##
FROM ${WIN_BASE_IMAGE}

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

COPY --from=build /src/otelcol-contrib.exe ./
COPY configs/otelcol-contrib.yaml config.yaml

ENV NO_WINDOWS_SERVICE=1

ENTRYPOINT ["otelcol-contrib.exe"]
CMD ["--config", "config.yaml"]
EXPOSE 13133 14250 14268 4317 6060 8888 9411 9443 9080
