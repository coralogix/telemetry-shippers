SHELL := /bin/bash

# Configuration
RELEASE ?= ecs-ec2-example
CHART_PATH ?= .
VALUES_FILE ?= $(CHART_PATH)/values.yaml
OUTPUT_DIR ?= $(CHART_PATH)/examples
OTEL_CONFIG_FILE ?= $(OUTPUT_DIR)/otel-config.yaml
OTEL_CONFIG_EBPF_FILE ?= $(OUTPUT_DIR)/otel-config-ebpf.yaml
MANIFEST_FILE ?= $(OUTPUT_DIR)/manifest.yaml
MANIFEST_EBPF_FILE ?= $(OUTPUT_DIR)/manifest-ebpf.yaml
EBPF_ENABLE_SET ?= --set opentelemetry-ebpf-profiler.enabled=true

HELM ?= helm
YQ ?= yq

.PHONY: all otel-config otel-config-ebpf manifest manifest-ebpf

all: otel-config manifest

# Render only the OpenTelemetry config (no Kubernetes wrapper)
otel-config:
	@command -v $(HELM) >/dev/null 2>&1 || { echo "Error: helm not found in PATH" >&2; exit 1; }
	@command -v $(YQ) >/dev/null 2>&1 || { echo "Error: yq not found in PATH" >&2; exit 1; }
	@mkdir -p $(OUTPUT_DIR)
	@$(HELM) dependency build $(CHART_PATH) >/dev/null
	@$(HELM) template $(RELEASE) $(CHART_PATH) -f $(VALUES_FILE) \
		| $(YQ) eval -r 'select(.kind == "ConfigMap") | .metadata.name'
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

# Render OpenTelemetry config with eBPF profiler enabled via --set
otel-config-ebpf:
	@command -v $(HELM) >/dev/null 2>&1 || { echo "Error: helm not found in PATH" >&2; exit 1; }
	@command -v $(YQ) >/dev/null 2>&1 || { echo "Error: yq not found in PATH" >&2; exit 1; }
	@mkdir -p $(OUTPUT_DIR)
	@$(HELM) dependency build $(CHART_PATH) >/dev/null
	@$(HELM) template $(RELEASE) $(CHART_PATH) -f $(VALUES_FILE) $(EBPF_ENABLE_SET) \
		| $(YQ) eval -r 'select(.kind == "ConfigMap") | .metadata.name'
	@$(HELM) template $(RELEASE) $(CHART_PATH) -f $(VALUES_FILE) $(EBPF_ENABLE_SET) \
		| $(YQ) eval -r 'select(.kind == "ConfigMap") | .data.relay' - > $(OTEL_CONFIG_EBPF_FILE)
	@echo "Wrote $(OTEL_CONFIG_EBPF_FILE)"

# Render full Helm manifest with eBPF profiler enabled via --set
manifest-ebpf:
	@command -v $(HELM) >/dev/null 2>&1 || { echo "Error: helm not found in PATH" >&2; exit 1; }
	@mkdir -p $(OUTPUT_DIR)
	@$(HELM) dependency build $(CHART_PATH) >/dev/null
	@$(HELM) template $(RELEASE) $(CHART_PATH) -f $(VALUES_FILE) $(EBPF_ENABLE_SET) > $(MANIFEST_EBPF_FILE)
	@echo "Wrote $(MANIFEST_EBPF_FILE)"
