SHELL := /bin/bash

.PHONY: help check-prereqs test setup validate \
	create-kind-cluster delete-kind-cluster \
	install-kube-prometheus-stack create-coralogix-secret install-otel-integration \
	wait-for-workloads check-kubelet-servicemonitor \
	check-target-allocator-jobs check-target-allocator-scrape-configs \
	check-debug-exporter-config check-servicemonitor-metrics clean

KIND_CLUSTER_NAME ?= otel-integration-target-allocator
KIND_KUBECONFIG ?= /tmp/kind-otel-integration-target-allocator
KIND_NODE_IMAGE ?= kindest/node:v1.30.0

KUBECTL := KUBECONFIG=$(KIND_KUBECONFIG) kubectl
HELM := KUBECONFIG=$(KIND_KUBECONFIG) helm

KPS_RELEASE ?= kps
KPS_NAMESPACE ?= monitoring
KPS_CHART ?= prometheus-community/kube-prometheus-stack
KPS_VALUES ?= values-kube-prometheus-stack.yaml

OTEL_RELEASE ?= otel-ta
OTEL_NAMESPACE ?= coralogix-otel
OTEL_CHART ?= ../../k8s-helm
OTEL_VALUES ?= values-target-allocator.yaml
CORALOGIX_SECRET_NAME ?= coralogix-keys
CORALOGIX_API_KEY ?= dummy-private-key

OTEL_AGENT_DAEMONSET ?= target-allocator-opentelemetry-agent
OTEL_AGENT_CONFIGMAP ?= target-allocator-opentelemetry-agent
TARGET_ALLOCATOR_SERVICE ?= target-allocator-opentelemetry-targetallocator
TARGET_ALLOCATOR_PORT_FORWARD_PORT ?= 18080
WAIT_TIMEOUT ?= 12m

help:
	@echo "Available targets:"
	@echo "  test                          - Full end-to-end setup + validation"
	@echo "  setup                         - Create kind cluster and install all components"
	@echo "  validate                      - Run all validation checks"
	@echo "  create-kind-cluster           - Create kind cluster and write kubeconfig"
	@echo "  install-kube-prometheus-stack - Install kube-prometheus-stack"
	@echo "  create-coralogix-secret       - Create coralogix-keys secret"
	@echo "  install-otel-integration      - Install otel-integration with target allocator"
	@echo "  clean                         - Uninstall releases and delete kind cluster"

check-prereqs:
	@set -eu; \
	for cmd in kind kubectl helm docker curl rg yq jq; do \
		command -v "$$cmd" >/dev/null || { echo "Missing required command: $$cmd"; exit 1; }; \
	done

test: setup validate
	@echo "Target allocator kind test completed successfully."

setup: check-prereqs create-kind-cluster install-kube-prometheus-stack create-coralogix-secret install-otel-integration wait-for-workloads
	@echo "Setup completed."

validate: check-kubelet-servicemonitor check-target-allocator-jobs check-target-allocator-scrape-configs check-debug-exporter-config check-servicemonitor-metrics
	@echo "Validation completed."

create-kind-cluster:
	@set -euo pipefail; \
	if kind get clusters 2>/dev/null | rg -xq "$(KIND_CLUSTER_NAME)"; then \
		echo "Kind cluster '$(KIND_CLUSTER_NAME)' already exists, reusing it."; \
	else \
		echo "Creating kind cluster '$(KIND_CLUSTER_NAME)'..."; \
		if [ -n "$(KIND_NODE_IMAGE)" ]; then \
			kind create cluster --name "$(KIND_CLUSTER_NAME)" --image "$(KIND_NODE_IMAGE)"; \
		else \
			kind create cluster --name "$(KIND_CLUSTER_NAME)"; \
		fi; \
	fi; \
	kind get kubeconfig --name "$(KIND_CLUSTER_NAME)" > "$(KIND_KUBECONFIG)"; \
	$(KUBECTL) cluster-info >/dev/null

delete-kind-cluster:
	@set -euo pipefail; \
	if kind get clusters 2>/dev/null | rg -xq "$(KIND_CLUSTER_NAME)"; then \
		kind delete cluster --name "$(KIND_CLUSTER_NAME)"; \
	fi; \
	rm -f "$(KIND_KUBECONFIG)"

install-kube-prometheus-stack:
	@set -euo pipefail; \
	$(HELM) repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true; \
	$(HELM) repo update >/dev/null; \
	$(HELM) upgrade --install "$(KPS_RELEASE)" "$(KPS_CHART)" \
		--namespace "$(KPS_NAMESPACE)" \
		--create-namespace \
		-f "$(KPS_VALUES)"; \
	$(KUBECTL) -n "$(KPS_NAMESPACE)" rollout status deployment/"$(KPS_RELEASE)"-kube-prometheus-stack-operator --timeout="$(WAIT_TIMEOUT)"

create-coralogix-secret:
	@set -euo pipefail; \
	$(KUBECTL) create namespace "$(OTEL_NAMESPACE)" --dry-run=client -o yaml | $(KUBECTL) apply -f -; \
	$(KUBECTL) -n "$(OTEL_NAMESPACE)" create secret generic "$(CORALOGIX_SECRET_NAME)" \
		--from-literal=PRIVATE_KEY="$(CORALOGIX_API_KEY)" \
		--dry-run=client -o yaml | $(KUBECTL) apply -f -

install-otel-integration:
	@set -euo pipefail; \
	$(HELM) dependency build "$(OTEL_CHART)" >/dev/null; \
	$(HELM) upgrade --install "$(OTEL_RELEASE)" "$(OTEL_CHART)" \
		--namespace "$(OTEL_NAMESPACE)" \
		--create-namespace \
		-f "$(OTEL_VALUES)"; \
	$(KUBECTL) -n "$(OTEL_NAMESPACE)" rollout status daemonset/"$(OTEL_AGENT_DAEMONSET)" --timeout="$(WAIT_TIMEOUT)"; \
	$(KUBECTL) -n "$(OTEL_NAMESPACE)" rollout status deployment/"$(TARGET_ALLOCATOR_SERVICE)" --timeout="$(WAIT_TIMEOUT)"

wait-for-workloads:
	@set -euo pipefail; \
	$(KUBECTL) -n "$(OTEL_NAMESPACE)" get pods -o wide; \
	$(KUBECTL) -n "$(KPS_NAMESPACE)" get pods -o wide

check-kubelet-servicemonitor:
	@set -euo pipefail; \
	$(KUBECTL) -n "$(KPS_NAMESPACE)" get servicemonitors.monitoring.coreos.com | rg -n "kubelet"; \
	echo "kube-prometheus-stack kubelet ServiceMonitor detected."

check-target-allocator-jobs:
	@set -euo pipefail; \
	PF_LOG=$$(mktemp /tmp/ta-jobs-portforward.XXXXXX); \
	$(KUBECTL) -n "$(OTEL_NAMESPACE)" port-forward svc/"$(TARGET_ALLOCATOR_SERVICE)" "$(TARGET_ALLOCATOR_PORT_FORWARD_PORT)":80 > "$$PF_LOG" 2>&1 & \
	PF_PID=$$!; \
	trap 'kill "$$PF_PID" >/dev/null 2>&1 || true' EXIT; \
	for i in $$(seq 1 30); do \
		if curl -fsS "http://127.0.0.1:$(TARGET_ALLOCATOR_PORT_FORWARD_PORT)/jobs" > /tmp/target-allocator-jobs.json 2>/dev/null; then \
			break; \
		fi; \
		sleep 1; \
	done; \
	test -s /tmp/target-allocator-jobs.json || { echo "Failed to query /jobs"; cat "$$PF_LOG"; exit 1; }; \
	rg -qi "kubelet" /tmp/target-allocator-jobs.json; \
	echo "Target allocator /jobs includes kubelet targets."

check-target-allocator-scrape-configs:
	@set -euo pipefail; \
	PF_LOG=$$(mktemp /tmp/ta-scrape-portforward.XXXXXX); \
	$(KUBECTL) -n "$(OTEL_NAMESPACE)" port-forward svc/"$(TARGET_ALLOCATOR_SERVICE)" "$(TARGET_ALLOCATOR_PORT_FORWARD_PORT)":80 > "$$PF_LOG" 2>&1 & \
	PF_PID=$$!; \
	trap 'kill "$$PF_PID" >/dev/null 2>&1 || true' EXIT; \
	for i in $$(seq 1 30); do \
		if curl -fsS "http://127.0.0.1:$(TARGET_ALLOCATOR_PORT_FORWARD_PORT)/scrape_configs" > /tmp/target-allocator-scrape-configs.json 2>/dev/null; then \
			break; \
		fi; \
		sleep 1; \
	done; \
	test -s /tmp/target-allocator-scrape-configs.json || { echo "Failed to query /scrape_configs"; cat "$$PF_LOG"; exit 1; }; \
	rg -qi "kubelet" /tmp/target-allocator-scrape-configs.json; \
	echo "Target allocator /scrape_configs includes kubelet config."

check-debug-exporter-config:
	@set -euo pipefail; \
	$(KUBECTL) -n "$(OTEL_NAMESPACE)" get configmap "$(OTEL_AGENT_CONFIGMAP)" -o json | jq -r '.data.relay' > /tmp/target-allocator-opentelemetry-agent-relay.yaml; \
	test "$$(yq '.exporters.debug.verbosity' /tmp/target-allocator-opentelemetry-agent-relay.yaml)" = "detailed"; \
	yq '.service.pipelines.metrics.exporters[]' /tmp/target-allocator-opentelemetry-agent-relay.yaml | rg -xq "debug"; \
	echo "Debug exporter is configured with detailed verbosity in metrics pipeline."

check-servicemonitor-metrics:
	@set -euo pipefail; \
	AGENT_POD=$$($(KUBECTL) -n "$(OTEL_NAMESPACE)" get pods -l app.kubernetes.io/name=opentelemetry-agent,component=agent-collector -o jsonpath='{.items[0].metadata.name}'); \
	test -n "$$AGENT_POD"; \
	$(KUBECTL) -n "$(OTEL_NAMESPACE)" logs pod/"$$AGENT_POD" --since=10m > /tmp/target-allocator-agent-debug.log; \
	rg -q "scrape_pool\":\"serviceMonitor/" /tmp/target-allocator-agent-debug.log; \
	rg -q "service: Str\\($(KPS_RELEASE)-kube-prometheus-stack-" /tmp/target-allocator-agent-debug.log; \
	echo "ServiceMonitor metrics are present in debug exporter logs."

clean:
	@set -euo pipefail; \
	if [ -f "$(KIND_KUBECONFIG)" ]; then \
		$(HELM) uninstall "$(OTEL_RELEASE)" -n "$(OTEL_NAMESPACE)" >/dev/null 2>&1 || true; \
		$(HELM) uninstall "$(KPS_RELEASE)" -n "$(KPS_NAMESPACE)" >/dev/null 2>&1 || true; \
	fi; \
	$(MAKE) delete-kind-cluster
