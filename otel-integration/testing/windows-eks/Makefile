# Makefile for managing EKS Windows test flow for otel-integration
# Prerequisites: eksctl, aws CLI, kubectl, helm, rg

.PHONY: help create-windows-cluster delete-windows-cluster write-kubeconfig \
	create-coralogix-secret install-otel-integration-windows deploy-windows-log-generator \
	setup-windows verify-debug-settings verify-windows-log-collection \
	uninstall-otel-integration delete-windows-log-generator

EKS_WINDOWS_PROFILE ?= research
EKS_WINDOWS_REGION ?= eu-west-1
EKS_WINDOWS_CLUSTER ?= otel-integration-windows-cluster
EKS_WINDOWS_CONFIG ?= eks-windows.yaml
EKS_WINDOWS_CONFIG_RENDERED ?= /tmp/eks-windows-$(EKS_WINDOWS_CLUSTER)-$(EKS_WINDOWS_REGION).yaml
EKS_WINDOWS_AWS_ENV := AWS_PROFILE=$(EKS_WINDOWS_PROFILE) AWS_REGION=$(EKS_WINDOWS_REGION) AWS_DEFAULT_REGION=$(EKS_WINDOWS_REGION)

WINDOWS_NAMESPACE ?= coralogix-otel
WINDOWS_RELEASE ?= otel-windows
WINDOWS_CHART ?= ../../k8s-helm
WINDOWS_VALUES_BASE ?= ../../k8s-helm/values-windows.yaml
WINDOWS_VALUES_DEBUG ?= values-windows-debug.yaml
LINUX_AGENT_DAEMONSET ?= coralogix-opentelemetry-agent
WINDOWS_AGENT_DAEMONSET ?= coralogix-opentelemetry-windows-agent
WINDOWS_AGENT_CONFIGMAP ?= coralogix-opentelemetry-windows-agent
CORALOGIX_SECRET_NAME ?= coralogix-keys
CORALOGIX_DOMAIN ?= eu2.coralogix.com

WINDOWS_WORKLOAD_NAMESPACE ?= default
WINDOWS_LOG_GENERATOR_MANIFEST ?= windows-log-generator.yaml
WINDOWS_LOG_GENERATOR_DEPLOYMENT ?= windows-log-generator
WINDOWS_LOG_MARKER ?= WINDOWS-OTEL-LOG-CHECK

help:
	@echo "Available targets:"
	@echo "  create-windows-cluster        - Create the mixed Linux/Windows EKS cluster"
	@echo "  write-kubeconfig              - Write kubeconfig for the Windows EKS cluster"
	@echo "  create-coralogix-secret       - Create/update Coralogix API key secret"
	@echo "  install-otel-integration-windows - Install otel-integration in Windows mode"
	@echo "  deploy-windows-log-generator  - Deploy a Windows workload that emits test logs"
	@echo "  setup-windows                 - Create secret, install integration, deploy workload"
	@echo "  verify-debug-settings         - Verify debug exporter detailed verbosity and logLevel=debug"
	@echo "  verify-windows-log-collection - Verify Windows workload logs are exported by collector debug exporter"
	@echo "  delete-windows-log-generator  - Delete test Windows workload"
	@echo "  uninstall-otel-integration    - Uninstall otel-integration release"
	@echo "  delete-windows-cluster        - Delete the EKS cluster"
	@echo ""
	@echo "Important env vars:"
	@echo "  CORALOGIX_API_KEY             - Required for create-coralogix-secret/setup-windows"
	@echo "  CORALOGIX_DOMAIN              - Coralogix domain, default: eu2.coralogix.com"
	@echo "  EKS_WINDOWS_PROFILE           - AWS profile, default: research"
	@echo "  EKS_WINDOWS_REGION            - AWS region, default: eu-west-1"

create-windows-cluster:
	@echo "Creating Windows EKS cluster..."
	sed \
		-e "s/^\\(  name: \\).*/\\1$(EKS_WINDOWS_CLUSTER)/" \
		-e "s/^\\(  region: \\).*/\\1$(EKS_WINDOWS_REGION)/" \
		$(EKS_WINDOWS_CONFIG) > $(EKS_WINDOWS_CONFIG_RENDERED)
	$(EKS_WINDOWS_AWS_ENV) eksctl create cluster -f $(EKS_WINDOWS_CONFIG_RENDERED)
	@$(MAKE) write-kubeconfig
	@echo "Windows EKS cluster created."

write-kubeconfig:
	@echo "Writing kubeconfig for cluster $(EKS_WINDOWS_CLUSTER)..."
	$(EKS_WINDOWS_AWS_ENV) eksctl utils write-kubeconfig --cluster $(EKS_WINDOWS_CLUSTER) --region $(EKS_WINDOWS_REGION)
	@echo "kubeconfig updated."

create-coralogix-secret:
	@test -n "$(CORALOGIX_API_KEY)" || (echo "CORALOGIX_API_KEY is required" && exit 1)
	kubectl create namespace $(WINDOWS_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	kubectl -n $(WINDOWS_NAMESPACE) create secret generic $(CORALOGIX_SECRET_NAME) \
		--from-literal=PRIVATE_KEY="$(CORALOGIX_API_KEY)" \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "Coralogix secret is ready."

install-otel-integration-windows:
	@echo "Installing otel-integration in Windows mode..."
	helm upgrade --install $(WINDOWS_RELEASE) $(WINDOWS_CHART) \
		--namespace $(WINDOWS_NAMESPACE) \
		--create-namespace \
		-f $(WINDOWS_VALUES_BASE) \
		-f $(WINDOWS_VALUES_DEBUG) \
		--set global.clusterName=$(EKS_WINDOWS_CLUSTER) \
		--set global.domain=$(CORALOGIX_DOMAIN)
	kubectl rollout status daemonset/$(LINUX_AGENT_DAEMONSET) -n $(WINDOWS_NAMESPACE) --timeout=15m
	kubectl rollout status daemonset/$(WINDOWS_AGENT_DAEMONSET) -n $(WINDOWS_NAMESPACE) --timeout=15m
	kubectl rollout status deployment/coralogix-opentelemetry-collector -n $(WINDOWS_NAMESPACE) --timeout=15m
	@echo "Windows-mode otel-integration installed."

deploy-windows-log-generator:
	@echo "Deploying Windows log generator..."
	kubectl apply -n $(WINDOWS_WORKLOAD_NAMESPACE) -f $(WINDOWS_LOG_GENERATOR_MANIFEST)
	kubectl rollout status deployment/$(WINDOWS_LOG_GENERATOR_DEPLOYMENT) -n $(WINDOWS_WORKLOAD_NAMESPACE) --timeout=15m
	@echo "Windows log generator deployed."

setup-windows: create-coralogix-secret install-otel-integration-windows deploy-windows-log-generator
	@echo "Windows test stack is ready."

verify-debug-settings:
	@echo "Verifying collector config for detailed debug exporter and debug logs..."
	@set -e; \
		kubectl -n $(WINDOWS_NAMESPACE) get configmap $(WINDOWS_AGENT_CONFIGMAP) -o yaml | rg -q "verbosity: detailed"; \
		kubectl -n $(WINDOWS_NAMESPACE) get configmap $(WINDOWS_AGENT_CONFIGMAP) -o yaml | rg -q "level: 'debug'|level: debug"; \
		kubectl -n $(WINDOWS_NAMESPACE) get configmap $(WINDOWS_AGENT_CONFIGMAP) -o yaml | rg -q "\\- debug"; \
		echo "Verified: debug exporter (detailed) and collector debug logs are enabled."

verify-windows-log-collection:
	@echo "Verifying workload emits logs..."
	kubectl logs deployment/$(WINDOWS_LOG_GENERATOR_DEPLOYMENT) -n $(WINDOWS_WORKLOAD_NAMESPACE) --tail=60 | rg -n "$(WINDOWS_LOG_MARKER)"
	@echo "Verifying Windows collector exports the workload logs through debug exporter..."
	kubectl -n $(WINDOWS_NAMESPACE) logs daemonset/$(WINDOWS_AGENT_DAEMONSET) --since=20m --tail=4000 --max-log-requests=20 | rg -n "$(WINDOWS_LOG_MARKER)"
	@echo "Verified: Windows logs are collected by otel-integration."

delete-windows-log-generator:
	kubectl delete -n $(WINDOWS_WORKLOAD_NAMESPACE) -f $(WINDOWS_LOG_GENERATOR_MANIFEST) --ignore-not-found
	@echo "Windows log generator deleted."

uninstall-otel-integration:
	helm uninstall $(WINDOWS_RELEASE) -n $(WINDOWS_NAMESPACE) || true
	@echo "otel-integration release removed (if it existed)."

delete-windows-cluster:
	@echo "Deleting Windows EKS cluster..."
	$(EKS_WINDOWS_AWS_ENV) eksctl delete cluster --name=$(EKS_WINDOWS_CLUSTER) --region=$(EKS_WINDOWS_REGION)
	@echo "Windows EKS cluster deleted."
