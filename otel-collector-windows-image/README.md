## OpenTelemetry Collector (Contrib Distribution) Docker Image for Windows

This is an (unofficial) Docker image for the OpenTelemetry Collector Contrib distribution, based on the [official OpenTelemetry Collector](https://github.com/open-telemetry/opentelemetry-collector-releases/releases) Windows releases.

These images are published on [Docker Hub](https://hub.docker.com/r/coralogixrepo/opentelemetry-collector-contrib-windows). The tag version always corresponds to the official OpenTelemetry Collector release version.

Depending on your Windows server version you can use images:
- For Windows 2019: `coralogixrepo/opentelemetry-collector-contrib-windows:latest`, `coralogixrepo/opentelemetry-collector-contrib-windows:<semantic_version>`
- For Windows 2022: `coralogixrepo/opentelemetry-collector-contrib-windows:<semantic_version>-windows2022`

Images are only available for the `amd64` platform.

## Building Windows image on MacOS / Linux

It's possible to build the image from the Dockerfile in this directory, with following steps:
1. Create a new buildx builder:

```
docker buildx create --name img-builder --use --driver docker-container --driver-opt image=moby/buildkit:v0.9.3 
```

2. Build the image for Windows platform:

```
docker buildx build --load --platform windows/amd64 -t <your_tag> .
```
