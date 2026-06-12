SHELL := /bin/bash

RELEASE ?= coralogix-windows-standalone
CHART_PATH ?= .
VALUES_FILE ?= $(CHART_PATH)/values.yaml
OUTPUT_DIR ?= $(CHART_PATH)/build
OTEL_CONFIG_FILE ?= $(abspath $(OUTPUT_DIR)/otel-config.yaml)

HELM ?= helm
YQ ?= yq

.PHONY: all otel-config helm-template clean

all: otel-config

# Render only the OpenTelemetry collector configuration
otel-config:
	@command -v $(HELM) >/dev/null 2>&1 || { echo "Error: helm not found in PATH" >&2; exit 1; }
	@command -v $(YQ) >/dev/null 2>&1 || { echo "Error: yq not found in PATH" >&2; exit 1; }
	@mkdir -p $(OUTPUT_DIR)
	@$(HELM) dependency build $(CHART_PATH) >/dev/null
	@$(HELM) template $(RELEASE) $(CHART_PATH) -f $(VALUES_FILE) \
		| $(YQ) eval -r 'select(.kind == "ConfigMap") | .data.relay' - > $(OTEL_CONFIG_FILE)
	@echo "Wrote $(OTEL_CONFIG_FILE)"

# Convenience target to inspect rendered manifests
helm-template:
	@$(HELM) template $(RELEASE) $(CHART_PATH) -f $(VALUES_FILE)

clean:
	@rm -rf $(OUTPUT_DIR)

