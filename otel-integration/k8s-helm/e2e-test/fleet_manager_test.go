package e2e

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/open-telemetry/opentelemetry-collector-contrib/pkg/xk8stest"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

func TestE2E_FleetManager(t *testing.T) {
	t.Parallel()

	testServer, err := newOpampTestServer()
	assert.NoError(t, err)

	testServerAddr := "localhost"
	if hostedAddr := os.Getenv("HOSTENDPOINT"); hostedAddr != "" {
		testServerAddr = hostedAddr
	}

	err = testServer.start(fmt.Sprintf("%s:4320", testServerAddr))
	assert.NoError(t, err)
	t.Cleanup(func() {
		_ = testServer.stop()
	})

	// Get the kubeconfig path from env
	kubeconfigPath := testKubeConfig
	if kubeConfigFromEnv := os.Getenv(kubeConfigEnvVar); kubeConfigFromEnv != "" {
		kubeconfigPath = kubeConfigFromEnv
	}

	k8sClient, err := xk8stest.NewK8sClient(kubeconfigPath)
	require.NoError(t, err)

	// We give a kick to all the Collector to trigger them to reconnect to the
	// OpAMP server, decreasing the likelyhood of a false positive in the test.
	gvr := schema.GroupVersionResource{Group: "", Version: "v1", Resource: "pods"}
	err = k8sClient.
		DynamicClient.
		Resource(gvr).
		Namespace("").
		DeleteCollection(
			context.Background(),
			metav1.DeleteOptions{},
			metav1.ListOptions{LabelSelector: "app.kubernetes.io/instance=otel-integration-agent-e2e"},
		)
	require.NoError(t, err)

	ctx := context.Background()
	ctxWithTimeout, cancel := context.WithTimeout(ctx, 30*time.Second)
	t.Cleanup(cancel)

	// We wait for at least two messages:
	// 1st: reporting the creation of the agent.
	// 2nd: reporting the agent's initial configuration.
	// More messages might have arrived, but we don't care about the extra ones at the moment.
	testServer.assertMessageCount(t, ctxWithTimeout, 2)
}
