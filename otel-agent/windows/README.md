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