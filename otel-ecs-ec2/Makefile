SHELL := /bin/bash

# Configuration
RELEASE ?= ecs-ec2-example
CHART_PATH ?= .
VALUES_FILE ?= $(CHART_PATH)/values.yaml
OUTPUT_DIR ?= $(CHART_PATH)/examples
OTEL_CONFIG_FILE ?= $(OUTPUT_DIR)/otel-config.yaml
MANIFEST_FILE ?= $(OUTPUT_DIR)/manifest.yaml

HELM ?= helm
YQ ?= yq

.PHONY: all otel-config manifest

all: otel-config manifest

# Render only the OpenTelemetry config (no Kubernetes wrapper)
otel-config:
	@command -v $(HELM) >/dev/null 2>&1 || { echo "Error: helm not found in PATH" >&2; exit 1; }
	@command -v $(YQ) >/dev/null 2>&1 || { echo "Error: yq not found in PATH" >&2; exit 1; }
	@mkdir -p $(OUTPUT_DIR)
	@$(HELM) dependency build $(CHART_PATH) >/dev/null
	@$(HELM) template $(RELEASE) $(CHART_PATH) -f $(VALUES_FILE) \
		| $(YQ) eval -r 'select(.kind == "ConfigMap") | .data.relay' - > $(OTEL_CONFIG_FILE)
	@echo "Wrote $(OTEL_CONFIG_FILE)"

# Render full Helm manifest (all Kubernetes resources)
manifest:
	@command -v $(HELM) >/dev/null 2>&1 || { echo "Error: helm not found in PATH" >&2; exit 1; }
	@mkdir -p $(OUTPUT_DIR)
	@$(HELM) dependency build $(CHART_PATH) >/dev/null
	@$(HELM) template $(RELEASE) $(CHART_PATH) -f $(VALUES_FILE) > $(MANIFEST_FILE)
	@echo "Wrote $(MANIFEST_FILE)"
