# OpenTelemetry Supervised Collector (Coralogix distro) Makefile

# Default values
IMAGE_NAME ?= coralogix-otel-supervised-cdot
IMAGE_TAG ?= latest
SUPERVISOR_VERSION ?= $(shell cat CURRENT_SUPERVISOR_VERSION)
COLLECTOR_VERSION ?= $(shell cat CURRENT_COLLECTOR_VERSION)
PLATFORMS ?= linux/amd64,linux/arm64

# Docker build arguments
DOCKER_BUILDARGS := --build-arg COLLECTOR_VERSION=$(COLLECTOR_VERSION) --build-arg SUPERVISOR_VERSION=$(SUPERVISOR_VERSION)

FULL_IMAGE_NAME = $(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: build
build: ## Build the container image
	docker build $(DOCKER_BUILDARGS) -t $(FULL_IMAGE_NAME) .

.PHONY: run
run: ## Run the built image with the default configuration
	docker run --rm -it \
		-v ./examples/collector.yaml:/etc/otelcol-contrib/config.yaml \
		-v ./examples/supervisor.yaml:/etc/otelcol-contrib/supervisor.yaml \
		-e CORALOGIX_PRIVATE_KEY=$(echo $CX_TOKEN) \
		$(FULL_IMAGE_NAME) \
		-config /etc/otelcol-contrib/supervisor.yaml

.PHONY: build-multiarch
build-multiarch: ## Build the multiarch container image
	docker buildx build $(DOCKER_BUILDARGS) \
		--platform $(PLATFORMS) \
		-t $(FULL_IMAGE_NAME) \
		.

.PHONY: build-multiarch-push
build-multiarch-push: ## Build and push the multiarch container image
	docker buildx build $(DOCKER_BUILDARGS) \
		--platform $(PLATFORMS) \
		-t $(FULL_IMAGE_NAME) \
		--push .

.PHONY: help
help:
	@echo 'Usage: make [target] [VARIABLE=value]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-22s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ''
	@echo 'Variables:'
	@echo '  IMAGE_NAME             Docker image name (default: coralogix-otel-supervised-cdot)'
	@echo '  IMAGE_TAG              Docker image tag (default: latest)'
	@echo '  COLLECTOR_VERSION      Coralogix OTEL Collector version (default: contents of CURRENT_COLLECTOR_VERSION)'
	@echo '  SUPERVISOR_VERSION     OpAMP Supervisor version (default: contents of CURRENT_SUPERVISOR_VERSION)'
	@echo '  PLATFORMS              Target platforms for multi-arch builds (default: linux/amd64,linux/arm64)'
	@echo ''
	@echo 'Examples:'
	@echo '  make build'
	@echo '  make build COLLECTOR_VERSION=v0.5.7'
	@echo '  make build SUPERVISOR_VERSION=0.141.0'
	@echo '  make build COLLECTOR_VERSION=v0.5.7 SUPERVISOR_VERSION=0.141.0'
	@echo '  make build IMAGE_TAG=v1.0.0' IMAGE_NAME=coralogix-otel-supervised-cdot
	@echo '  make build-multiarch'
	@echo '  make build-multiarch-push'
.DEFAULT_GOAL := help
