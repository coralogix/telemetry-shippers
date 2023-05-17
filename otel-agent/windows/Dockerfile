FROM --platform=$BUILDPLATFORM curlimages/curl AS build
WORKDIR /src
RUN curl -Lo otelcol.tar.gz https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.77.0/otelcol_0.77.0_windows_amd64.tar.gz ; \
    tar -xzvf otelcol.tar.gz

## 
FROM mcr.microsoft.com/windows/nanoserver:1809

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# WORKDIR "C:\otel"

COPY --from=build /src/otelcol.exe ./

ENV NO_WINDOWS_SERVICE=1
EXPOSE 13133 14250 14268 4317 6060 8888 9411 9443 9080

# COPY config.yaml .

ENTRYPOINT ["C:\\otelcol.exe", "--config=config.yaml"]