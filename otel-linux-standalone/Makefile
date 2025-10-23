SHELL := /bin/bash

RELEASE ?= eco-system-linux
CHART_PATH ?= .
VALUES_FILE ?= $(CHART_PATH)/values.yaml
OUTPUT_DIR ?= $(CHART_PATH)/build
OTEL_CONFIG_FILE ?= $(abspath $(OUTPUT_DIR)/otel-config.yaml)
TERRAFORM_DIR ?= $(CHART_PATH)/terraform

AWS_PROFILE ?= research
AWS_REGION ?= eu-west-1
SSH_KEY_NAME ?= eco-system-linux-collector-key
SSH_PUBLIC_KEY_PATH ?= $(HOME)/.ssh/id_rsa.pub
SSH_PRIVATE_KEY_PATH ?= $(HOME)/.ssh/id_rsa
INSTANCE_TYPE ?= t3.small
TELEMETRYGEN_DIR ?= $(CHART_PATH)/terraform-telemetrygen
TELEMETRYGEN_KEY_NAME ?= eco-system-telemetrygen-key
TELEMETRYGEN_INSTANCE_TYPE ?= t3.micro
COLLECTOR_ENDPOINT ?=
ENABLE_TELEMETRYGEN ?= false
TELEMETRYGEN_ENDPOINT ?= 127.0.0.1:4317
TELEMETRYGEN_RATE ?= 25
TELEMETRYGEN_SERVICE_NAME ?= eco-system-telemetrygen
TELEMETRYGEN_DURATION ?= inf
TELEMETRYGEN_VERSION ?= v0.137.0
TELEMETRYGEN_GO_VERSION ?= 1.24.0
CORALOGIX_API_KEY ?= $(API_KEY)

HELM ?= helm
YQ ?= yq
TF ?= terraform

TF_VARS ?= \
	-var="aws_region=$(AWS_REGION)" \
	-var="otel_config_path=$(OTEL_CONFIG_FILE)" \
	-var="ssh_key_name=$(SSH_KEY_NAME)" \
	-var="ssh_public_key_path=$(SSH_PUBLIC_KEY_PATH)" \
	-var="ssh_private_key_path=$(SSH_PRIVATE_KEY_PATH)" \
	-var="instance_type=$(INSTANCE_TYPE)" \
	-var="enable_telemetrygen=$(ENABLE_TELEMETRYGEN)" \
	-var="telemetrygen_otlp_endpoint=$(TELEMETRYGEN_ENDPOINT)" \
	-var="telemetrygen_rate_per_second=$(TELEMETRYGEN_RATE)" \
	-var="telemetrygen_service_name=$(TELEMETRYGEN_SERVICE_NAME)" \
	-var="telemetrygen_duration=$(TELEMETRYGEN_DURATION)" \
	-var="telemetrygen_version=$(TELEMETRYGEN_VERSION)" \
	-var="telemetrygen_go_version=$(TELEMETRYGEN_GO_VERSION)" \
	-var="coralogix_api_key=$(CORALOGIX_API_KEY)"

TELEMETRYGEN_TF_VARS ?= \
	-var="aws_region=$(AWS_REGION)" \
	-var="ssh_key_name=$(TELEMETRYGEN_KEY_NAME)" \
	-var="ssh_public_key_path=$(SSH_PUBLIC_KEY_PATH)" \
	-var="ssh_private_key_path=$(SSH_PRIVATE_KEY_PATH)" \
	-var="instance_type=$(TELEMETRYGEN_INSTANCE_TYPE)" \
	-var="collector_endpoint=$(COLLECTOR_ENDPOINT)"

.PHONY: all otel-config helm-template terraform-init terraform-apply terraform-destroy terraform-output deploy destroy clean telemetrygen-init telemetrygen-apply telemetrygen-destroy telemetrygen-output

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
	@AWS_PROFILE=$(AWS_PROFILE) AWS_SDK_LOAD_CONFIG=1 $(TF) -chdir=$(TERRAFORM_DIR) apply -auto-approve -no-color $(TF_VARS)

terraform-destroy: terraform-init
	@AWS_PROFILE=$(AWS_PROFILE) AWS_SDK_LOAD_CONFIG=1 $(TF) -chdir=$(TERRAFORM_DIR) destroy -auto-approve -no-color $(TF_VARS)

terraform-output:
	@AWS_PROFILE=$(AWS_PROFILE) AWS_SDK_LOAD_CONFIG=1 $(TF) -chdir=$(TERRAFORM_DIR) output

deploy: otel-config terraform-apply

destroy: terraform-destroy

clean:
	@rm -rf $(OUTPUT_DIR)

telemetrygen-init:
	@$(TF) -chdir=$(TELEMETRYGEN_DIR) init -backend=false

telemetrygen-apply: telemetrygen-init
	@[ -n "$(COLLECTOR_ENDPOINT)" ] || { echo "Error: COLLECTOR_ENDPOINT must be set (e.g. COLLECTOR_ENDPOINT=1.2.3.4:4317)"; exit 1; }
	@AWS_PROFILE=$(AWS_PROFILE) AWS_SDK_LOAD_CONFIG=1 $(TF) -chdir=$(TELEMETRYGEN_DIR) apply -auto-approve -no-color $(TELEMETRYGEN_TF_VARS)

telemetrygen-destroy: telemetrygen-init
	@[ -n "$(COLLECTOR_ENDPOINT)" ] || { echo "Error: COLLECTOR_ENDPOINT must be set (matches the value used during apply)"; exit 1; }
	@AWS_PROFILE=$(AWS_PROFILE) AWS_SDK_LOAD_CONFIG=1 $(TF) -chdir=$(TELEMETRYGEN_DIR) destroy -auto-approve -no-color $(TELEMETRYGEN_TF_VARS)

telemetrygen-output:
	@AWS_PROFILE=$(AWS_PROFILE) AWS_SDK_LOAD_CONFIG=1 $(TF) -chdir=$(TELEMETRYGEN_DIR) output
