IMAGE_REPOSITORY ?= telemetrygen-windows
IMAGE_TAG ?= 0.121.0-windows2022
TELEMETRYGEN_VERSION ?= 0.121.0

.PHONY: build push

build:
	docker build --platform linux/amd64 --build-arg TELEMETRYGEN_VERSION=$(TELEMETRYGEN_VERSION) -t $(IMAGE_REPOSITORY):$(IMAGE_TAG) .

push: build
	docker push $(IMAGE_REPOSITORY):$(IMAGE_TAG)
