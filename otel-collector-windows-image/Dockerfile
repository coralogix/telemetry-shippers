# escape=`
# For Windows 2022, use `mcr.microsoft.com/windows/servercore:ltsc2022`
ARG WIN_BASE_IMAGE=mcr.microsoft.com/windows/servercore:ltsc2019

# hadolint ignore=DL3006,DL3029
FROM --platform=$BUILDPLATFORM curlimages/curl AS build
WORKDIR /src
RUN curl -Lo otelcol.tar.gz https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.121.0/otelcol-contrib_0.121.0_windows_amd64.tar.gz
# hadolint ignore=DL3059
RUN tar -xzvf otelcol.tar.gz

##
# hadolint ignore=DL3006
FROM ${WIN_BASE_IMAGE}

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# hadolint ignore=DL3045
COPY --from=build /src/otelcol-contrib.exe ./
# hadolint ignore=DL3045
COPY configs/otelcol-contrib.yaml config.yaml

ENV NO_WINDOWS_SERVICE=1

ENTRYPOINT ["otelcol-contrib.exe"]
CMD ["--config", "config.yaml"]
EXPOSE 13133 14250 14268 4317 6060 8888 9411 9443 9080
