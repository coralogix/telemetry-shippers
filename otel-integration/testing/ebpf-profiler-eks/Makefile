# Makefile for managing EKS eBPF profiler test stack
# Prerequisites: eksctl, kubectl, aws CLI configured

.PHONY: help create-ebpf-profiler clean-ebpf-profiler test-ebpf-profiler-presets \
	create-ebpf-secret install-ebpf-profiler deploy-telemetrygen setup-ebpf-profiler \
	check-ebpf-profiler-logs check-cluster-collector-config

EKS_EBPF_PROFILE ?= research
EKS_EBPF_REGION ?= eu-central-1
EKS_EBPF_CLUSTER ?= otel-integration-ebpf-profiler
EKS_EBPF_CONFIG ?= eks-ebpf-profiler.yaml
EKS_EBPF_AWS_ENV := AWS_PROFILE=$(EKS_EBPF_PROFILE) AWS_REGION=$(EKS_EBPF_REGION) AWS_DEFAULT_REGION=$(EKS_EBPF_REGION)

EBPF_NAMESPACE ?= coralogix-otel
EBPF_RELEASE ?= otel-ebpf-profiler
EBPF_VALUES ?= values-ebpf-profiler.yaml
EBPF_CHART ?= ../../k8s-helm
COLLECTOR_CHART ?= ../../k8s-helm/charts/opentelemetry-collector-0.128.17.tgz
CORALOGIX_SECRET_NAME ?= coralogix-keys
EBPF_DEPLOYMENT_ENV ?= ebpf-eks
EBPF_ANNOTATION_SERVICE ?= ebpf-annotated-service

TELEMETRYGEN_NAMESPACE ?= default
TELEMETRYGEN_NAME ?= ebpf-telemetrygen
TELEMETRYGEN_MANIFEST ?= telemetrygen-traces.yaml

help:
	@echo "Available targets:"
	@echo "  create-ebpf-profiler - Create EKS cluster for eBPF profiling (AL2023)"
	@echo "  clean-ebpf-profiler  - Delete eBPF profiler EKS cluster"
	@echo "  test-ebpf-profiler-presets - Render Helm templates for preset checks"
	@echo "  create-ebpf-secret - Create/update Coralogix API key secret"
	@echo "  install-ebpf-profiler - Install eBPF profiler + agent + cluster collector"
	@echo "  deploy-telemetrygen   - Deploy telemetrygen workload"
	@echo "  setup-ebpf-profiler   - Create secret, install stack, deploy telemetrygen"
	@echo "  check-cluster-collector-config - Verify annotation discovery config"
	@echo "  check-ebpf-profiler-logs - Check profiler logs for required attributes"

# Create eBPF profiler cluster
create-ebpf-profiler:
	@echo "Creating eBPF profiler EKS cluster..."
	$(EKS_EBPF_AWS_ENV) eksctl create cluster -f $(EKS_EBPF_CONFIG)
	$(EKS_EBPF_AWS_ENV) eksctl utils write-kubeconfig --cluster $(EKS_EBPF_CLUSTER) --region $(EKS_EBPF_REGION)
	@echo "eBPF profiler cluster created successfully!"

# Clean up eBPF profiler cluster
clean-ebpf-profiler:
	@echo "Deleting eBPF profiler EKS cluster..."
	$(EKS_EBPF_AWS_ENV) eksctl delete cluster --name=$(EKS_EBPF_CLUSTER) --region=$(EKS_EBPF_REGION)
	@echo "eBPF profiler cluster deleted successfully!"

# Render Helm templates for preset checks
test-ebpf-profiler-presets:
	@echo "Rendering resource detection preset..."
	helm template my-collector $(COLLECTOR_CHART) \
		--set presets.resourceDetection.enabled=true \
		--set presets.resourceDetection.deploymentEnvironmentName=$(EBPF_DEPLOYMENT_ENV) \
		| rg -n "OTEL_RESOURCE_ATTRIBUTES|deployment.environment.name"
	@echo "Rendering eBPF profiler + profiles K8s attributes presets..."
	helm template my-collector $(COLLECTOR_CHART) \
		--set presets.ebpfProfiler.enabled=true \
		--set presets.profilesK8sAttributes.enabled=true \
		--set presets.profilesK8sAttributes.serviceLabels[0].tag_name=service.label \
		--set presets.profilesK8sAttributes.serviceLabels[0].key=app.kubernetes.io/name \
		--set presets.profilesK8sAttributes.serviceLabels[0].from=pod \
		--set presets.profilesK8sAttributes.serviceAnnotations[0].tag_name=service.annotation \
		--set presets.profilesK8sAttributes.serviceAnnotations[0].key=app.coralogix.com/service \
		--set presets.profilesK8sAttributes.serviceAnnotations[0].from=pod \
		| rg -n "transform/profiles|k8sattributes/profiles|service.label|service.annotation"
	@echo "Rendering annotation discovery preset..."
	helm template my-collector $(COLLECTOR_CHART) \
		--set presets.prometheusAnnotationDiscovery.enabled=true \
		--set presets.prometheusAnnotationDiscovery.observePods=true \
		--set presets.prometheusAnnotationDiscovery.observeServices=false \
		| rg -n "receiver_creator|k8s_observer|prometheus_simple"

# Create/update Coralogix API key secret
create-ebpf-secret:
	@test -n "$(CORALOGIX_API_KEY)" || (echo "CORALOGIX_API_KEY is required" && exit 1)
	kubectl create namespace $(EBPF_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	kubectl -n $(EBPF_NAMESPACE) create secret generic $(CORALOGIX_SECRET_NAME) \
		--from-literal=PRIVATE_KEY="$(CORALOGIX_API_KEY)" \
		--dry-run=client -o yaml | kubectl apply -f -

# Install eBPF profiler via Helm
install-ebpf-profiler:
	@echo "Installing eBPF profiler + agent + cluster collector..."
	helm upgrade --install $(EBPF_RELEASE) $(EBPF_CHART) \
		--namespace $(EBPF_NAMESPACE) \
		--create-namespace \
		-f $(EBPF_VALUES)
	kubectl rollout status daemonset/coralogix-opentelemetry-agent -n $(EBPF_NAMESPACE)
	kubectl rollout status deployment/coralogix-opentelemetry-collector -n $(EBPF_NAMESPACE)
	kubectl rollout status daemonset/$(EBPF_RELEASE)-opentelemetry-ebpf-profiler-agent -n $(EBPF_NAMESPACE)
	@echo "eBPF profiler install complete."

# Deploy telemetrygen workload
deploy-telemetrygen:
	@echo "Deploying telemetrygen..."
	kubectl apply -n $(TELEMETRYGEN_NAMESPACE) -f $(TELEMETRYGEN_MANIFEST)
	kubectl rollout status deployment/$(TELEMETRYGEN_NAME) -n $(TELEMETRYGEN_NAMESPACE)
	@echo "Telemetrygen deployed."

# Install stack and deploy telemetrygen
setup-ebpf-profiler: create-ebpf-secret install-ebpf-profiler deploy-telemetrygen
	@echo "eBPF profiler setup complete."

# Verify cluster collector config includes annotation discovery
check-cluster-collector-config:
	kubectl -n $(EBPF_NAMESPACE) get configmap coralogix-opentelemetry-collector -o yaml \
		| rg -n "receiver_creator|k8s_observer|prometheus_simple"

# Check eBPF profiler logs for deployment environment name and service name
check-ebpf-profiler-logs:
	kubectl -n $(EBPF_NAMESPACE) logs daemonset/$(EBPF_RELEASE)-opentelemetry-ebpf-profiler-agent --since=20m \
		| rg -n "deployment.environment.name: Str\\($(EBPF_DEPLOYMENT_ENV)\\)|service.name: Str\\($(EBPF_ANNOTATION_SERVICE)\\)"
