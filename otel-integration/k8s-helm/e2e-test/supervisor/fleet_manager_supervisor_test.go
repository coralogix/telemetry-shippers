package supervisor

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"coralogix.com/otel-integration/e2e/internal/opampserver"
	"coralogix.com/otel-integration/e2e/internal/testhelpers"
	"github.com/open-telemetry/opamp-go/protobufs"
	"github.com/open-telemetry/opentelemetry-collector-contrib/pkg/xk8stest"
	"github.com/stretchr/testify/require"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

const (
	testKubeConfig   = "/tmp/kind-otel-integration-agent-e2e"
	kubeConfigEnvVar = "KUBECONFIG"
)

func TestE2E_FleetManagerSupervisor(t *testing.T) {
	host := testhelpers.HostEndpoint(t)
	testServer, opampPort := opampserver.StartTestServerOnFreePort(t, "0.0.0.0")
	k8sClient := newFleetManagerK8sClient(t)
	setSupervisorConfigEndpoint(t, k8sClient, defaultOpampEndpoint())
	rawConfig := assertSupervisorConfigRendered(t, k8sClient)
	expectedClusterName := extractConfigValue(rawConfig, "cx.cluster.name")
	require.NotEmpty(t, expectedClusterName, "expected cx.cluster.name in supervisor config")
	setSupervisorConfigEndpoint(t, k8sClient, opampEndpoint(host, opampPort))
	assertSupervisorConfigOverride(t, k8sClient, host, opampPort)
	kickFleetManagerCollectors(t, k8sClient)
	waitForFleetManagerMessages(t, testServer)
	assertMinimalCollectorConfig(t, k8sClient)
	assertSupervisorPodCommand(t, k8sClient)

	ctxWithTimeout, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	t.Cleanup(cancel)
	msg := waitForOpampMessage(t, ctxWithTimeout, testServer, func(msg *protobufs.AgentToServer) bool {
		agentType, ok := getNonIdentifyingAttribute(msg, "cx.agent.type")
		customAttr, customOK := getNonIdentifyingAttribute(msg, "e2e.custom.attr")
		clusterName, clusterOK := getNonIdentifyingAttribute(msg, "cx.cluster.name")
		namespaceName, nsOK := getNonIdentifyingAttribute(msg, "k8s.namespace.name")
		podName, podOK := getNonIdentifyingAttribute(msg, "k8s.pod.name")
		nodeName, nodeOK := getNonIdentifyingAttribute(msg, "k8s.node.name")
		return ok && agentType != "" && customOK && customAttr != "" && clusterOK && clusterName != "" &&
			nsOK && namespaceName != "" && podOK && podName != "" && nodeOK && nodeName != ""
	})

	value, ok := getNonIdentifyingAttribute(msg, "cx.agent.type")
	require.True(t, ok, "missing cx.agent.type in agent description")
	require.Equal(t, "agent", value)

	customAttr, ok := getNonIdentifyingAttribute(msg, "e2e.custom.attr")
	require.True(t, ok, "missing custom attributes in agent description")
	require.Equal(t, "supervisor", customAttr)

	clusterName, ok := getNonIdentifyingAttribute(msg, "cx.cluster.name")
	require.True(t, ok, "missing cx.cluster.name in agent description")
	require.Equal(t, expectedClusterName, clusterName)

	namespaceName, ok := getNonIdentifyingAttribute(msg, "k8s.namespace.name")
	require.True(t, ok, "missing k8s.namespace.name in agent description")
	require.Equal(t, agentCollectorNamespace(), namespaceName)

	_, ok = getNonIdentifyingAttribute(msg, "k8s.pod.name")
	require.True(t, ok, "missing k8s.pod.name in agent description")

	_, ok = getNonIdentifyingAttribute(msg, "k8s.node.name")
	require.True(t, ok, "missing k8s.node.name in agent description")
}

func TestE2E_FleetManagerSupervisor_ConfigMapReload(t *testing.T) {
	host := testhelpers.HostEndpoint(t)
	testServer, firstPort := opampserver.StartTestServerOnFreePort(t, "0.0.0.0")
	secondaryServer, secondPort := opampserver.StartTestServerOnFreePort(t, "0.0.0.0")
	k8sClient := newFleetManagerK8sClient(t)
	setSupervisorConfigEndpoint(t, k8sClient, defaultOpampEndpoint())
	assertSupervisorConfigRendered(t, k8sClient)

	setSupervisorConfigEndpoint(t, k8sClient, opampEndpoint(host, firstPort))
	kickFleetManagerCollectors(t, k8sClient)
	waitForFleetManagerMessages(t, testServer)

	setSupervisorConfigEndpoint(t, k8sClient, opampEndpoint(host, secondPort))
	kickFleetManagerCollectors(t, k8sClient)
	waitForFleetManagerMessages(t, secondaryServer)
}

func newFleetManagerK8sClient(t *testing.T) *xk8stest.K8sClient {
	t.Helper()

	kubeconfigPath := testKubeConfig
	if kubeConfigFromEnv := os.Getenv(kubeConfigEnvVar); kubeConfigFromEnv != "" {
		kubeconfigPath = kubeConfigFromEnv
	}

	k8sClient, err := xk8stest.NewK8sClient(kubeconfigPath)
	require.NoError(t, err)
	return k8sClient
}

func kickFleetManagerCollectors(t *testing.T, k8sClient *xk8stest.K8sClient) {
	t.Helper()

	gvr := schema.GroupVersionResource{Group: "", Version: "v1", Resource: "pods"}
	err := k8sClient.
		DynamicClient.
		Resource(gvr).
		Namespace("default").
		DeleteCollection(
			context.Background(),
			metav1.DeleteOptions{},
			metav1.ListOptions{LabelSelector: "app.kubernetes.io/instance=otel-integration-agent-e2e"},
		)
	require.NoError(t, err)
}

func waitForFleetManagerMessages(t *testing.T, testServer *opampserver.Server) {
	t.Helper()

	ctx := context.Background()
	ctxWithTimeout, cancel := context.WithTimeout(ctx, 30*time.Second)
	t.Cleanup(cancel)

	testServer.AssertMessageCount(t, ctxWithTimeout, 2)
}

func assertSupervisorConfigOverride(t *testing.T, k8sClient *xk8stest.K8sClient, host string, port int) {
	t.Helper()

	data := getConfigMapData(t, k8sClient, fmt.Sprintf("%s-supervisor", agentServiceName()))
	rawConfig := getConfigMapDataString(t, data, "supervisor.yaml")
	require.Contains(t, rawConfig, opampEndpoint(host, port))
	require.Contains(t, rawConfig, "e2e.custom.attr")
	require.Contains(t, rawConfig, "supervisor")
}

func assertMinimalCollectorConfig(t *testing.T, k8sClient *xk8stest.K8sClient) {
	t.Helper()

	data := getConfigMapData(t, k8sClient, fmt.Sprintf("%s-agent", agentServiceName()))
	relayConfig := getConfigMapDataString(t, data, "relay")
	require.Contains(t, relayConfig, "receivers:\n  nop:")
	require.Contains(t, relayConfig, "exporters:\n  nop:")
	require.Contains(t, relayConfig, "extensions:\n  health_check:")
}

func waitForOpampMessage(
	t *testing.T,
	ctx context.Context,
	server *opampserver.Server,
	predicate func(*protobufs.AgentToServer) bool,
) *protobufs.AgentToServer {
	t.Helper()

	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			t.Fatalf("timeout waiting for OpAMP message: %v", ctx.Err())
		case <-ticker.C:
			for _, msg := range server.MessagesSnapshot() {
				if predicate(msg) {
					return msg
				}
			}
		}
	}
}

func getNonIdentifyingAttribute(msg *protobufs.AgentToServer, key string) (string, bool) {
	if msg == nil || msg.GetAgentDescription() == nil {
		return "", false
	}

	for _, kv := range msg.GetAgentDescription().GetNonIdentifyingAttributes() {
		if kv.GetKey() == key {
			return kv.GetValue().GetStringValue(), true
		}
	}
	return "", false
}

func getConfigMapData(t *testing.T, k8sClient *xk8stest.K8sClient, name string) map[string]interface{} {
	t.Helper()

	gvr := corev1.SchemeGroupVersion.WithResource("configmaps")
	configMap, err := k8sClient.DynamicClient.Resource(gvr).Namespace(agentCollectorNamespace()).Get(
		context.Background(),
		name,
		metav1.GetOptions{},
	)
	require.NoError(t, err)

	data, ok := configMap.Object["data"].(map[string]interface{})
	require.True(t, ok, "configmap data missing")
	return data
}

func getConfigMapDataString(t *testing.T, data map[string]interface{}, key string) string {
	t.Helper()

	value, ok := data[key].(string)
	require.True(t, ok, "%s not found in configmap data", key)
	return value
}

func assertSupervisorConfigRendered(t *testing.T, k8sClient *xk8stest.K8sClient) string {
	t.Helper()

	data := getConfigMapData(t, k8sClient, fmt.Sprintf("%s-supervisor", agentServiceName()))
	rawConfig := getConfigMapDataString(t, data, "supervisor.yaml")
	require.Contains(t, rawConfig, defaultOpampEndpoint())
	require.Contains(t, rawConfig, "Authorization:")
	require.Contains(t, rawConfig, "Bearer ${env:CORALOGIX_PRIVATE_KEY}")
	return rawConfig
}

func setSupervisorConfigEndpoint(t *testing.T, k8sClient *xk8stest.K8sClient, toEndpoint string) {
	t.Helper()

	data := getConfigMapData(t, k8sClient, fmt.Sprintf("%s-supervisor", agentServiceName()))
	rawConfig := getConfigMapDataString(t, data, "supervisor.yaml")
	lines := strings.Split(rawConfig, "\n")
	updated := false
	for i, line := range lines {
		if strings.Contains(line, "endpoint:") && strings.Contains(line, "opamp") {
			prefix := strings.SplitN(line, "endpoint:", 2)[0]
			lines[i] = fmt.Sprintf("%sendpoint: %q", prefix, toEndpoint)
			updated = true
			break
		}
	}
	require.True(t, updated, "opamp endpoint not found in supervisor config")

	updatedConfig := strings.Join(lines, "\n")
	if rawConfig == updatedConfig {
		return
	}

	gvr := corev1.SchemeGroupVersion.WithResource("configmaps")
	configMapName := fmt.Sprintf("%s-supervisor", agentServiceName())
	configMap, err := k8sClient.DynamicClient.Resource(gvr).Namespace(agentCollectorNamespace()).Get(
		context.Background(),
		configMapName,
		metav1.GetOptions{},
	)
	require.NoError(t, err)

	configMap.Object["data"].(map[string]interface{})["supervisor.yaml"] = updatedConfig
	_, err = k8sClient.DynamicClient.Resource(gvr).Namespace(agentCollectorNamespace()).Update(
		context.Background(),
		configMap,
		metav1.UpdateOptions{},
	)
	require.NoError(t, err)
}

func defaultOpampEndpoint() string {
	return "https://ingress.coralogix.com/opamp/v1"
}

func opampEndpoint(host string, port int) string {
	return fmt.Sprintf("http://%s:%d/v1/opamp", host, port)
}

func extractConfigValue(rawConfig, key string) string {
	for _, line := range strings.Split(rawConfig, "\n") {
		trimmed := strings.TrimSpace(line)
		prefix := fmt.Sprintf("%s:", key)
		if strings.HasPrefix(trimmed, prefix) {
			value := strings.TrimSpace(strings.TrimPrefix(trimmed, prefix))
			return strings.Trim(value, "\"")
		}
	}
	return ""
}

func assertSupervisorPodCommand(t *testing.T, k8sClient *xk8stest.K8sClient) {
	t.Helper()

	podName := waitForSupervisorPod(t, k8sClient)
	pod, err := k8sClient.DynamicClient.Resource(corev1.SchemeGroupVersion.WithResource("pods")).Namespace(agentCollectorNamespace()).Get(
		context.Background(),
		podName,
		metav1.GetOptions{},
	)
	require.NoError(t, err)

	spec, ok := pod.Object["spec"].(map[string]interface{})
	require.True(t, ok, "pod spec missing")
	containers, ok := spec["containers"].([]interface{})
	require.True(t, ok && len(containers) > 0, "pod containers missing")
	container, ok := containers[0].(map[string]interface{})
	require.True(t, ok, "pod container missing")
	command, ok := container["command"].([]interface{})
	require.True(t, ok, "pod command missing")
	require.GreaterOrEqual(t, len(command), 2, "pod command should include executable and config")
	require.Equal(t, "/opampsupervisor", command[0])
	require.Equal(t, "--config=/etc/otelcol-contrib/supervisor.yaml", command[1])
}

func waitForSupervisorPod(t *testing.T, k8sClient *xk8stest.K8sClient) string {
	t.Helper()

	var podName string
	require.Eventually(t, func() bool {
		pods, err := k8sClient.DynamicClient.Resource(corev1.SchemeGroupVersion.WithResource("pods")).Namespace(agentCollectorNamespace()).List(context.Background(), metav1.ListOptions{
			LabelSelector: "component=agent-collector",
		})
		require.NoError(t, err)
		if len(pods.Items) == 0 {
			return false
		}
		for _, pod := range pods.Items {
			status, ok := pod.Object["status"].(map[string]any)
			if !ok {
				continue
			}
			phase, _ := status["phase"].(string)
			if phase == string(corev1.PodRunning) {
				podName = pod.GetName()
				return true
			}
		}
		return false
	}, 2*time.Minute, 2*time.Second, "supervisor pod not ready")
	return podName
}

func expectedChartVersion() string {
	return extractChartVersion(readChartYaml())
}

func readChartYaml() string {
	root, err := findRepoRoot()
	if err != nil {
		return ""
	}
	data, err := os.ReadFile(fmt.Sprintf("%s/otel-integration/k8s-helm/Chart.yaml", root))
	if err != nil {
		return ""
	}
	return string(data)
}

func findRepoRoot() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}
	for {
		if _, err := os.Stat(fmt.Sprintf("%s/otel-integration/k8s-helm/Chart.yaml", dir)); err == nil {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", fmt.Errorf("repo root not found")
		}
		dir = parent
	}
}

func extractChartVersion(source string) string {
	inDeps := false
	inAgent := false

	for _, line := range strings.Split(source, "\n") {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "dependencies:") {
			inDeps = true
			continue
		}
		if !inDeps {
			continue
		}
		if strings.HasPrefix(trimmed, "alias:") {
			inAgent = strings.Contains(trimmed, "opentelemetry-agent")
			continue
		}
		if inAgent && strings.HasPrefix(trimmed, "version:") {
			value := strings.TrimSpace(strings.TrimPrefix(trimmed, "version:"))
			return strings.Trim(value, "\"")
		}
	}
	return ""
}

func agentCollectorNamespace() string {
	if ns := os.Getenv("E2E_AGENT_NAMESPACE"); ns != "" {
		return ns
	}
	return "default"
}

func agentServiceName() string {
	if name := os.Getenv("E2E_AGENT_SERVICE"); name != "" {
		return name
	}
	return "coralogix-opentelemetry"
}
