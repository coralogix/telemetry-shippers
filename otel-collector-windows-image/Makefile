IMAGE_REPOSITORY ?= otel-col
IMAGE_TAG ?=
# A Windows version to build for. Supported values are `2019` and `2022`.
WIN_VERSION ?=
# This can be `--load` to just build the image and do nothing.
# It can also be `--push` to build and push the image.
POST_BUILD ?= --load

.phony: build-image
build-image:
	docker buildx build ${POST_BUILD} --platform windows/amd64 --build-arg WIN_BASE_IMAGE=mcr.microsoft.com/windows/servercore:ltsc${WIN_VERSION} -t ${IMAGE_REPOSITORY}:${IMAGE_TAG} .

win2019: WIN_VERSION=2019
win2019: IMAGE_TAG=win2019
win2019: build-image

win2022: WIN_VERSION=2022
win2022: IMAGE_TAG=win2022
win2022: build-image
