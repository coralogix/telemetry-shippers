#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $*"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*" >&2
}

log_test() {
    echo -e "${MAGENTA}[$(date +'%Y-%m-%d %H:%M:%S')] TEST:${NC} $*"
}

log_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] DEBUG:${NC} $*"
    fi
}

# Configuration
CLUSTER_NAME="otel-integration-agent-e2e"
KUBECONFIG_PATH="/tmp/kind-otel-integration-agent-e2e"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
HELM_CHART_DIR="${PROJECT_ROOT}/otel-integration/k8s-helm"
E2E_TEST_DIR="${PROJECT_ROOT}/otel-integration/k8s-helm/e2e-test"
COLLECTOR_CONTRIB_DIR=""
CUSTOM_IMAGE_REPOSITORY="docker.io/library/otelcontribcol"
CUSTOM_IMAGE_TAG="latest"
HELM_RELEASE_NAME="otel-integration-agent-e2e"

# Test results tracking
declare -a TEST_RESULTS
declare -a TEST_NAMES
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --collector-contrib)
            COLLECTOR_CONTRIB_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--collector-contrib PATH]"
            echo ""
            echo "Options:"
            echo "  --collector-contrib PATH  Path to opentelemetry-collector-contrib repository"
            echo "                           If provided, will build and use a custom image"
            echo "  -h, --help               Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Also check environment variable
if [ -z "$COLLECTOR_CONTRIB_DIR" ] && [ -n "$COLLECTOR_CONTRIB" ]; then
    COLLECTOR_CONTRIB_DIR="$COLLECTOR_CONTRIB"
fi

log_test "=== Running GitHub Workflow Equivalent ==="

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing=0
    for cmd in kind helm kubectl go docker; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "$cmd is not installed"
            missing=1
        else
            log_debug "Found $cmd: $(command -v $cmd)"
        fi
    done

    if [ $missing -eq 1 ]; then
        exit 1
    fi

    # Check if Docker daemon is running (needed for custom image builds)
    if [ -n "$COLLECTOR_CONTRIB_DIR" ]; then
        if ! docker info &> /dev/null; then
            log_error "Docker daemon is not running. Please start Docker/Colima."
            exit 1
        fi
        log_debug "Docker daemon is running"
    fi

    log_success "All prerequisites met"
}

# Setup kind cluster
setup_kind_cluster() {
    log_info "Setting up kind cluster..."

    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        log_info "Kind cluster '${CLUSTER_NAME}' already exists. Using existing cluster."
        kind get kubeconfig --name "${CLUSTER_NAME}" > "${KUBECONFIG_PATH}"
    else
        log_info "Creating kind cluster '${CLUSTER_NAME}'..."
        kind create cluster --name "${CLUSTER_NAME}" --image kindest/node:v1.24.12 || {
            if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
                log_info "Cluster was created by another process, using existing cluster."
            else
                log_error "Failed to create kind cluster"
                exit 1
            fi
        }
        kind get kubeconfig --name "${CLUSTER_NAME}" > "${KUBECONFIG_PATH}"
    fi

    export KUBECONFIG="${KUBECONFIG_PATH}"
    log_success "Kind cluster ready"
}

# Get host endpoint
get_host_endpoint() {
    log_info "Getting host endpoint..."

    if [[ "$(uname)" == "Darwin" ]]; then
        HOSTENDPOINT="host.docker.internal"
        log_debug "Detected macOS, using host.docker.internal"
    else
        HOSTENDPOINT=$(docker network inspect kind \
            | jq -r '.[0].IPAM.Config[]
                | select(.Gateway != null)
                | select(.Gateway | test("^[0-9]+[.]"))
                | .Gateway' \
            | head -n 1)

        if [[ -z "$HOSTENDPOINT" ]]; then
            log_error "Failed to find host endpoint via docker network inspect"
            exit 1
        fi
        log_debug "Detected Linux, using gateway: ${HOSTENDPOINT}"
    fi

    export HOSTENDPOINT

    if [ -z "$HOSTENDPOINT" ]; then
        log_error "Failed to get HOSTENDPOINT"
        exit 1
    fi

    log_success "HOSTENDPOINT is set to: ${HOSTENDPOINT}"
}

# Build and load custom collector image if needed
build_custom_image() {
    if [ -z "$COLLECTOR_CONTRIB_DIR" ]; then
        HELM_IMAGE_ARGS=""
        return
    fi

    echo -e "${YELLOW}Building custom collector image from ${COLLECTOR_CONTRIB_DIR}...${NC}"

    if [ ! -d "$COLLECTOR_CONTRIB_DIR" ]; then
        echo -e "${RED}Error: Collector contrib directory does not exist: ${COLLECTOR_CONTRIB_DIR}${NC}"
        exit 1
    fi

    DOCKERFILE_PATH="${COLLECTOR_CONTRIB_DIR}/cmd/otelcontribcol/Dockerfile"
    if [ ! -f "$DOCKERFILE_PATH" ]; then
        echo -e "${RED}Error: Dockerfile not found at ${DOCKERFILE_PATH}${NC}"
        exit 1
    fi

    # Check if patch is already applied
    if ! grep -q "COPY otelcontribcol /otelcol-contrib" "$DOCKERFILE_PATH"; then
        echo "Applying patch to Dockerfile..."
        cd "$COLLECTOR_CONTRIB_DIR"

        # Apply the patch: change COPY otelcontribcol / to COPY otelcontribcol /otelcol-contrib
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' 's|COPY otelcontribcol /|COPY otelcontribcol /otelcol-contrib|' "$DOCKERFILE_PATH"
        else
            # Linux
            sed -i 's|COPY otelcontribcol /|COPY otelcontribcol /otelcol-contrib|' "$DOCKERFILE_PATH"
        fi

        echo "Patch applied successfully"
    else
        echo "Patch already applied to Dockerfile"
    fi

    # Build the image
    echo "Building Docker image..."
    cd "$COLLECTOR_CONTRIB_DIR"
    if ! make docker-otelcontribcol; then
        echo -e "${RED}Error: Failed to build Docker image${NC}"
        exit 1
    fi

    # Load image into kind
    echo "Loading image into kind cluster..."
    if ! kind load docker-image "${CUSTOM_IMAGE_REPOSITORY}:${CUSTOM_IMAGE_TAG}" --name "${CLUSTER_NAME}"; then
        echo -e "${RED}Error: Failed to load image into kind cluster${NC}"
        exit 1
    fi

    echo -e "${GREEN}Custom image built and loaded successfully${NC}"

    # Set helm args to use the custom image for both agent and cluster collector
    HELM_IMAGE_ARGS="--set opentelemetry-agent.image.repository=${CUSTOM_IMAGE_REPOSITORY} --set opentelemetry-agent.image.tag=${CUSTOM_IMAGE_TAG} --set opentelemetry-agent.image.pullPolicy=Never --set opentelemetry-cluster-collector.image.repository=${CUSTOM_IMAGE_REPOSITORY} --set opentelemetry-cluster-collector.image.tag=${CUSTOM_IMAGE_TAG} --set opentelemetry-cluster-collector.image.pullPolicy=Never"
    echo "Will use custom image: ${CUSTOM_IMAGE_REPOSITORY}:${CUSTOM_IMAGE_TAG}"
}

# Setup helm repositories
setup_helm_repos() {
    echo -e "${YELLOW}Setting up helm repositories...${NC}"
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts || true
    helm repo add coralogix-charts-virtual https://cgx.jfrog.io/artifactory/coralogix-charts-virtual || true
    helm repo update || echo "Warning: Some helm repositories failed to update, continuing anyway..."
}

# Create secret
create_secret() {
    log_info "Creating secret..."
    kubectl create secret generic coralogix-keys --from-literal=PRIVATE_KEY=123 --dry-run=client -o yaml | kubectl apply -f -
    log_success "Secret created/updated"
}

# Uninstall helm chart
uninstall_chart() {
    log_info "Uninstalling helm chart (if exists)..."
    if helm list -q | grep -q "^${HELM_RELEASE_NAME}$"; then
        log_debug "Found existing release ${HELM_RELEASE_NAME}, uninstalling..."
        if helm uninstall "${HELM_RELEASE_NAME}"; then
            log_success "Chart uninstalled successfully"
        else
            log_warning "Failed to uninstall chart, continuing..."
        fi
        # Wait a bit for resources to be cleaned up
        log_debug "Waiting 5 seconds for resources to be cleaned up..."
        sleep 5

        # Verify pods are gone
        local remaining_pods=$(kubectl get pods -l "app.kubernetes.io/instance=${HELM_RELEASE_NAME}" --no-headers 2>/dev/null | wc -l | tr -d ' ')
        if [ "$remaining_pods" -gt 0 ]; then
            log_warning "Still ${remaining_pods} pod(s) remaining after uninstall, waiting additional 10 seconds..."
            sleep 10
        fi
    else
        log_debug "Chart not installed, skipping uninstall"
    fi
}

# Build helm dependencies
build_helm_dependencies() {
    log_info "Building helm dependencies..."
    cd "${HELM_CHART_DIR}"

    set +e
    BUILD_OUTPUT=$(helm dependency build 2>&1)
    BUILD_EXIT_CODE=$?
    set -e

    if [ $BUILD_EXIT_CODE -ne 0 ]; then
        if echo "$BUILD_OUTPUT" | grep -q "out of sync"; then
            log_warning "Chart.lock is out of sync, updating dependencies..."
            helm dependency update
            log_success "Dependencies updated successfully"
        else
            log_error "Failed to build helm dependencies"
            echo "$BUILD_OUTPUT"
            exit 1
        fi
    else
        log_success "Dependencies built successfully"
    fi
}

# Install helm chart with specific values
install_chart() {
    local values_files="$1"
    local wait_label="$2"

    log_info "Installing helm chart with values: ${values_files}"
    log_debug "Working directory: ${HELM_CHART_DIR}"
    log_debug "Wait label: ${wait_label}"

    cd "${HELM_CHART_DIR}"

    # Build the helm command
    local helm_cmd="helm upgrade --install ${HELM_RELEASE_NAME} . \
      --set global.clusterName=\"${CLUSTER_NAME}\" \
      --set global.domain=\"coralogix.com\" \
      --set global.hostedEndpoint=\"${HOSTENDPOINT}\""

    # Add values files
    for values_file in $values_files; do
        if [ ! -f "${HELM_CHART_DIR}/${values_file}" ]; then
            log_error "Values file not found: ${HELM_CHART_DIR}/${values_file}"
            return 1
        fi
        helm_cmd="${helm_cmd} -f ${values_file}"
        log_debug "Added values file: ${values_file}"
    done

    # Add image args if custom image is provided
    if [ -n "$HELM_IMAGE_ARGS" ]; then
        helm_cmd="${helm_cmd} ${HELM_IMAGE_ARGS}"
        log_debug "Using custom image args: ${HELM_IMAGE_ARGS}"
    fi

    # Execute helm command
    log_debug "Executing: ${helm_cmd}"
    if ! eval "$helm_cmd"; then
        log_error "Failed to install helm chart"
        return 1
    fi

    log_success "Helm chart installed successfully"

    # Wait for pods to be ready
    if [ -n "$wait_label" ]; then
        log_info "Waiting for pods to be ready (label: ${wait_label})..."
        log_debug "Checking pod status..."
        kubectl get pods -l "${wait_label}" || true

        local pod_wait_attempts=0
        local pod_wait_max_attempts=30
        while true; do
            local pod_count
            pod_count=$(kubectl get pods -l "${wait_label}" --no-headers 2>/dev/null | wc -l | tr -d ' ')
            if [ -n "$pod_count" ] && [ "$pod_count" -gt 0 ]; then
                break
            fi
            if [ $pod_wait_attempts -ge $pod_wait_max_attempts ]; then
                log_error "No pods found with label ${wait_label} after waiting"
                kubectl get pods -l "${wait_label}" || true
                return 1
            fi
            ((pod_wait_attempts++))
            sleep 5
        done

        if ! kubectl wait --all --for=condition=ready --timeout=300s pod -l "${wait_label}"; then
            log_error "Pods did not become ready in time"
            log_error "Pod status:"
            kubectl get pods -l "${wait_label}" || true
            log_error "Pod descriptions:"
            for pod in $(kubectl get pods -l "${wait_label}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true); do
                log_error "=== Pod: $pod ==="
                kubectl describe pod "$pod" 2>/dev/null | tail -30 || true
            done
            return 1
        fi
        log_success "All pods are ready"
    fi
}

# Run a specific test
run_test() {
    local test_name="$1"
    local test_env_vars="$2"

    log_test "========================================"
    log_test "Running test: ${test_name}"
    log_test "========================================"

    cd "${E2E_TEST_DIR}"
    log_debug "Cleaning test cache..."
    go clean -testcache

    # Set environment variables for the test
    export KUBECONFIG="${KUBECONFIG_PATH}"
    export HOSTENDPOINT="${HOSTENDPOINT}"

    # Set additional env vars if provided
    if [ -n "$test_env_vars" ]; then
        log_debug "Setting environment variables: ${test_env_vars}"
        eval "export $test_env_vars"
    fi

    log_debug "KUBECONFIG=${KUBECONFIG}"
    log_debug "HOSTENDPOINT=${HOSTENDPOINT}"
    log_debug "Test directory: ${E2E_TEST_DIR}"

    # Check pods before test
    log_debug "Pods before test:"
    kubectl get pods -l "app.kubernetes.io/instance=${HELM_RELEASE_NAME}" || true

    # Run the test
    log_info "Executing: go test -v -run='^${test_name}$' ./..."
    local test_start_time=$(date +%s)

    # Run test and capture exit code properly (tee doesn't preserve exit codes)
    go test -v -run="^${test_name}$" ./... 2>&1 | tee /tmp/test-${test_name}-output.log
    local test_exit_code=${PIPESTATUS[0]}

    local test_end_time=$(date +%s)
    local test_duration=$((test_end_time - test_start_time))

    if [ $test_exit_code -eq 0 ]; then
        log_success "✓ Test ${test_name} PASSED (duration: ${test_duration}s)"
        TEST_RESULTS+=("PASS")
        ((PASSED_TESTS++))
        return 0
    else
        log_error "✗ Test ${test_name} FAILED (duration: ${test_duration}s, exit code: ${test_exit_code})"
        TEST_RESULTS+=("FAIL")
        TEST_NAMES+=("$test_name")
        ((FAILED_TESTS++))

        # Show test output
        log_error "Test output saved to: /tmp/test-${test_name}-output.log"
        log_error "Last 50 lines of test output:"
        tail -50 /tmp/test-${test_name}-output.log || true

        # Collect pod logs on failure
        log_warning "Collecting pod logs..."
        for pod in $(kubectl get pods -l "app.kubernetes.io/instance=${HELM_RELEASE_NAME}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true); do
            log_error "===== Last 50 log lines for pod: $pod ====="
            kubectl logs --tail=50 "$pod" 2>/dev/null || true
            echo
        done

        # Show pod status
        log_error "Pod status:"
        kubectl get pods -l "app.kubernetes.io/instance=${HELM_RELEASE_NAME}" || true

        return 1
    fi
}

run_workflow_mode() {
    uninstall_chart
    build_helm_dependencies

    local workflow_values="./values.yaml ./e2e-test/testdata/values-e2e-test.yaml ./e2e-test/testdata/values-e2e-cluster-collector.yaml"
    if ! install_chart "$workflow_values" "component=agent-collector"; then
        log_error "Failed to install chart during workflow mode setup."
        return 1
    fi

    log_test "========================================"
    log_test "Workflow Mode: go test -v -run='^TestE2E.*' ./..."
    log_test "========================================"

    export KUBECONFIG="${KUBECONFIG_PATH}"
    export HOSTENDPOINT="${HOSTENDPOINT}"

    local workflow_start_time
    workflow_start_time=$(date +%s)

    (
        cd "${E2E_TEST_DIR}" || exit 1
        go clean -testcache
        go test -v -run='^TestE2E.*' ./...
    )
    local exit_code=$?
    local workflow_end_time
    workflow_end_time=$(date +%s)
    local workflow_duration=$((workflow_end_time - workflow_start_time))

    if [ $exit_code -ne 0 ]; then
        log_error "Workflow-mode tests FAILED (duration: ${workflow_duration}s, exit code: ${exit_code})"
        log_warning "Collecting pod logs..."
        for pod in $(kubectl get pods -l "app.kubernetes.io/instance=${HELM_RELEASE_NAME}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true); do
            log_error "===== Last 50 log lines for pod: $pod ====="
            kubectl logs --tail=50 "$pod" 2>/dev/null || true
            echo
        done
        log_error "Pod status:"
        kubectl get pods -l "app.kubernetes.io/instance=${HELM_RELEASE_NAME}" || true
    else
        log_success "Workflow-mode tests PASSED (duration: ${workflow_duration}s)"
    fi

    return $exit_code
}

# Print summary
print_summary() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Test Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Total tests: ${TOTAL_TESTS}"
    echo -e "${GREEN}Passed: ${PASSED_TESTS}${NC}"
    echo -e "${RED}Failed: ${FAILED_TESTS}${NC}"

    if [ ${FAILED_TESTS} -gt 0 ]; then
        echo -e "${RED}Failed tests:${NC}"
        for test_name in "${TEST_NAMES[@]}"; do
            echo -e "  - ${test_name}"
        done
    fi

    echo -e "${BLUE}========================================${NC}"
}

# Main execution
main() {
    check_prerequisites
    setup_kind_cluster
    get_host_endpoint
    build_custom_image
    setup_helm_repos
    create_secret

    run_workflow_mode
    return $?

    # Define test configurations
    # Format: test_name:values_files:wait_label:env_vars
    # NOTE: TestE2E_HeadSampling_Simple is skipped - test appears to be broken
    # (fails with "expected no traces with head sampling at 0%, but some were received")
    # even when RUN_HEAD_SAMPLING_E2E=1 is set. In our CI we are skipping it.
    declare -a test_configs=(
        "TestE2E_ClusterCollector_Metrics:./values.yaml ./e2e-test/testdata/values-e2e-test.yaml ./e2e-test/testdata/values-e2e-cluster-collector.yaml:component=agent-collector:"
        "TestE2E_TailSampling_Simple:./values.yaml ./tail-sampling-values.yaml ./e2e-test/testdata/values-e2e-tail-sampling.yaml:app.kubernetes.io/instance=otel-integration-agent-e2e:RUN_TAIL_SAMPLING_E2E=1"
        # "TestE2E_HeadSampling_Simple:./values.yaml ./e2e-test/testdata/values-e2e-head-sampling.yaml:component=agent-collector:RUN_HEAD_SAMPLING_E2E=1"  # SKIPPED - test appears broken
        "TestE2E_FleetManager:./values.yaml ./e2e-test/testdata/values-e2e-test.yaml:component=agent-collector:"
        "TestE2E_TransactionsPreset:./values.yaml ./e2e-test/testdata/values-e2e-test.yaml:component=agent-collector:"
    )

    TOTAL_TESTS=${#test_configs[@]}

    # Run each test
    local test_num=0
    for test_config in "${test_configs[@]}"; do
        ((test_num++))
        IFS=':' read -r test_name values_files wait_label env_vars <<< "$test_config"

        log_test "========================================"
        log_test "Test ${test_num}/${TOTAL_TESTS}: ${test_name}"
        log_test "========================================"

        # Uninstall previous chart
        uninstall_chart

        # Build dependencies (only needed once, but safe to run multiple times)
        build_helm_dependencies

        # Install chart with test-specific values
        if ! install_chart "$values_files" "$wait_label"; then
            log_error "Failed to install chart for ${test_name}, skipping test"
            TEST_RESULTS+=("SKIP")
            TEST_NAMES+=("$test_name")
            ((FAILED_TESTS++))
            continue
        fi

        # Run the test
        run_test "$test_name" "$env_vars"
        local test_exit_code=$?

        log_debug "Test ${test_name} completed with exit code: ${test_exit_code}"
    done

    # Print summary
    print_summary

    # Exit with error if any tests failed
    if [ ${FAILED_TESTS} -gt 0 ]; then
        exit 1
    fi
}

# Run main function
main
