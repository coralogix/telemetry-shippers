SHELL := /bin/bash

RELEASE ?= otel-govcloud
CHART_PATH ?= .
VALUES_FILE ?= $(CHART_PATH)/values.yaml
OUTPUT_DIR ?= $(CHART_PATH)/build
OTEL_CONFIG_FILE ?= $(abspath $(OUTPUT_DIR)/otel-config.yaml)
TERRAFORM_DIR ?= $(CHART_PATH)/terraform

AWS_PROFILE ?= gov
AWS_REGION ?= us-gov-east-1
VAR_FILE ?= $(TERRAFORM_DIR)/dev.tfvars
INSTANCE_TYPE ?= t3.small
ENABLE_TELEMETRYGEN ?= false
TELEMETRYGEN_ENDPOINT ?= 127.0.0.1:4317
TELEMETRYGEN_RATE ?= 25
TELEMETRYGEN_SERVICE_NAME ?= otel-govcloud-telemetrygen
TELEMETRYGEN_DURATION ?= inf
TELEMETRYGEN_VERSION ?= v0.137.0
TELEMETRYGEN_GO_VERSION ?= 1.24.0
CORALOGIX_API_KEY ?= $(API_KEY)

HELM ?= helm
YQ ?= yq
TF ?= terraform

# otel_config_path must always point to the rendered config; passed as a var
# so Terraform picks up the latest rendered file on every apply.
TF_VARS ?= \
	-var="otel_config_path=$(OTEL_CONFIG_FILE)"

TF_VAR_FILE_FLAG ?= $(if $(VAR_FILE),-var-file="$(VAR_FILE)")

.PHONY: all otel-config helm-template terraform-init terraform-apply terraform-destroy terraform-output deploy destroy clean

all: deploy

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

terraform-init:
	@$(TF) -chdir=$(TERRAFORM_DIR) init -backend=false

terraform-apply: terraform-init
	@[ -f $(OTEL_CONFIG_FILE) ] || { echo "Error: $(OTEL_CONFIG_FILE) not found. Run 'make otel-config' first."; exit 1; }
	@[ -f $(VAR_FILE) ] || { echo "Error: var file $(VAR_FILE) not found."; exit 1; }
	@AWS_PROFILE=$(AWS_PROFILE) AWS_SDK_LOAD_CONFIG=1 $(TF) -chdir=$(TERRAFORM_DIR) apply -auto-approve -no-color $(TF_VAR_FILE_FLAG) $(TF_VARS)

terraform-destroy: terraform-init
	@[ -f $(VAR_FILE) ] || { echo "Error: var file $(VAR_FILE) not found."; exit 1; }
	@AWS_PROFILE=$(AWS_PROFILE) AWS_SDK_LOAD_CONFIG=1 $(TF) -chdir=$(TERRAFORM_DIR) destroy -auto-approve -no-color $(TF_VAR_FILE_FLAG) $(TF_VARS)

terraform-output:
	@AWS_PROFILE=$(AWS_PROFILE) AWS_SDK_LOAD_CONFIG=1 $(TF) -chdir=$(TERRAFORM_DIR) output

deploy: otel-config terraform-apply

destroy: terraform-destroy

clean:
	@rm -rf $(OUTPUT_DIR)
