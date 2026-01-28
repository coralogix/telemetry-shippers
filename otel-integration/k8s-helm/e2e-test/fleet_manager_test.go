package e2e

import (
	"context"
	"os"
	"testing"
	"time"

	"coralogix.com/otel-integration/e2e/internal/opampserver"
	"github.com/open-telemetry/opentelemetry-collector-contrib/pkg/xk8stest"
	"github.com/stretchr/testify/require"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

func TestE2E_FleetManager(t *testing.T) {
	t.Parallel()

	testServer := opampserver.StartTestServer(t, "0.0.0.0:4320")
	k8sClient := newFleetManagerK8sClient(t)
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
