package e2e

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"coralogix.com/otel-integration/e2e/internal/opampserver"
	"coralogix.com/otel-integration/e2e/internal/testhelpers"
	"github.com/open-telemetry/opentelemetry-collector-contrib/pkg/xk8stest"
	"github.com/stretchr/testify/require"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

func TestE2E_FleetManager(t *testing.T) {
	t.Parallel()

	k8sClient := newFleetManagerK8sClient(t)
	hostEndpoint := testhelpers.HostEndpoint(t)
	testServer, opampPort := opampserver.StartTestServerOnFreePort(t, "0.0.0.0")
	patchOpampEndpoint(t, k8sClient, hostEndpoint, opampPort)

	kickFleetManagerCollectors(t, k8sClient)
	waitForFleetManagerMessages(t, testServer)
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

	// We wait for at least two messages:
	// 1st: reporting the creation of the agent.
	// 2nd: reporting the agent's initial configuration.
	testServer.AssertMessageCount(t, ctxWithTimeout, 2)
}

func patchOpampEndpoint(t *testing.T, k8sClient *xk8stest.K8sClient, host string, port int) {
	t.Helper()

	gvr := corev1.SchemeGroupVersion.WithResource("configmaps")
	configMapName := fmt.Sprintf("%s-agent", agentServiceName())
	configMap, err := k8sClient.DynamicClient.Resource(gvr).Namespace(agentCollectorNamespace()).Get(
		context.Background(),
		configMapName,
		metav1.GetOptions{},
	)
	require.NoError(t, err)

	data, ok := configMap.Object["data"].(map[string]interface{})
	require.True(t, ok, "agent configmap data missing")
	rawConfig, ok := data["relay"].(string)
	require.True(t, ok, "relay config missing in agent configmap")

	fromEndpoint := fmt.Sprintf("http://%s:4320/v1/opamp", host)
	toEndpoint := fmt.Sprintf("http://%s:%d/v1/opamp", host, port)
	updatedConfig := strings.ReplaceAll(rawConfig, fromEndpoint, toEndpoint)
	require.NotEqual(t, rawConfig, updatedConfig, "expected opamp endpoint to change")

	data["relay"] = updatedConfig
	_, err = k8sClient.DynamicClient.Resource(gvr).Namespace(agentCollectorNamespace()).Update(
		context.Background(),
		configMap,
		metav1.UpdateOptions{},
	)
	require.NoError(t, err)
}
