package e2e

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/google/uuid"
	"github.com/open-telemetry/opentelemetry-collector-contrib/pkg/xk8stest"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/consumer/consumertest"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// TestE2E_TailSampling_Simple validates that when tail-sampling is configured
// to pass all spans, at least one span is received by the local OTLP sink.
//
// Prerequisites (helm install example):
//
//	helm upgrade --install otel-integration-agent-e2e . \
//	  --set global.clusterName="otel-integration-agent-e2e" \
//	  --set global.domain="coralogix.com" \
//	  --set global.hostedEndpoint=$HOSTENDPOINT \
//	  -f ./values.yaml \
//	  -f ./tail-sampling-values.yaml \
//	  -f ./e2e-test/testdata/values-e2e-tail-sampling.yaml
//
// Note: the e2e override routes gateway traces to $HOSTENDPOINT:6321.
func TestE2E_TailSampling_Simple(t *testing.T) {
	if os.Getenv("RUN_TAIL_SAMPLING_E2E") != "1" {
		t.Skip("skipping tail-sampling E2E; set RUN_TAIL_SAMPLING_E2E=1 to enable")
	}

	// Parity check with other E2E tests
	require.Equal(t, xk8stest.HostEndpoint(t), os.Getenv("HOSTENDPOINT"), "HostEndpoints does not match env and detected")

	testDataDir := filepath.Join("testdata")

	// Get the kubeconfig path from env
	kubeconfigPath := testKubeConfig
	if kubeConfigFromEnv := os.Getenv(kubeConfigEnvVar); kubeConfigFromEnv != "" {
		kubeconfigPath = kubeConfigFromEnv
	}

	k8sClient, err := xk8stest.NewK8sClient(kubeconfigPath)
	require.NoError(t, err)

	// Create the namespace specific for the test
	nsFile := filepath.Join(testDataDir, "namespace.yaml")
	buf, err := os.ReadFile(nsFile)
	require.NoErrorf(t, err, "failed to read namespace object file %s", nsFile)
	nsObj, err := xk8stest.CreateObject(k8sClient, buf)
	if err != nil {
		// If namespace already exists, fetch it and proceed
		if strings.Contains(err.Error(), "already exists") {
			existing, getErr := k8sClient.DynamicClient.Resource(corev1.SchemeGroupVersion.WithResource("namespaces")).Get(context.Background(), "e2e", metav1.GetOptions{})
			require.NoError(t, getErr)
			nsObj = existing
		} else {
			require.NoErrorf(t, err, "failed to create k8s namespace from file %s", nsFile)
		}
	}
	_ = nsObj.GetName()

	// Local OTLP sink for traces, must match values-e2e-tail-sampling.yaml (6321)
	tracesConsumer := new(consumertest.TracesSink)
	shutdownSink := StartUpSinks(t, ReceiverSinks{
		Traces: &TraceSinkConfig{
			Consumer: tracesConsumer,
			Ports: &ReceiverPorts{
				Grpc: 6321,
			},
		},
	})
	defer shutdownSink()

	// Generate traces via telemetrygen workloads
	testID := uuid.NewString()[:8]
	createTeleOpts := &xk8stest.TelemetrygenCreateOpts{
		ManifestsDir: filepath.Join(testDataDir, "telemetrygen"),
		TestID:       testID,
		DataTypes:    []string{"traces"},
	}
	telemetryGenObjs, telemetryGenObjInfos := xk8stest.CreateTelemetryGenObjects(t, k8sClient, createTeleOpts)
	for _, info := range telemetryGenObjInfos {
		xk8stest.WaitForTelemetryGenToStart(t, k8sClient, info.Namespace, info.PodLabelSelectors, info.Workload, info.DataType)
	}

	t.Cleanup(func() {
		_ = xk8stest.DeleteObject(k8sClient, nsObj)
		for _, obj := range telemetryGenObjs {
			_ = xk8stest.DeleteObject(k8sClient, obj)
		}
	})

	// With pass-all tail-sampling, any spans should reach the local sink
	waitForTraces(t, 1, tracesConsumer)
}
