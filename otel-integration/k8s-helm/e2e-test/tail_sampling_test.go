package e2e

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/open-telemetry/opentelemetry-collector-contrib/pkg/xk8stest"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/consumer/consumertest"
	"go.opentelemetry.io/collector/pdata/pcommon"
	"go.opentelemetry.io/collector/pdata/ptrace"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// TestE2E_TailSampling validates that:
// 1) Agent sends spans only to the Gateway via load balancing exporter
// 2) Gateway tail-sampling is configured to pass all traces to an OTLP exporter
// 3) The exporter receives spans (assert on the local OTLP sink)
//
// This test is opt-in to avoid interfering with default CI runs. Enable via:
//
//	RUN_TAIL_SAMPLING_E2E=1
//
// and install the chart with the tail-sampling overrides, e.g.:
//
//	helm upgrade --install otel-integration-agent-e2e . \
//	  --set global.clusterName="otel-integration-agent-e2e" \
//	  --set global.domain="coralogix.com" \
//	  --set global.hostedEndpoint=$HOSTENDPOINT \
//	  -f ./values.yaml \
//	  -f ./tail-sampling-values.yaml \
//	  -f ./e2e-test/testdata/values-e2e-tail-sampling.yaml
func TestE2E_TailSampling(t *testing.T) {
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
	require.NoErrorf(t, err, "failed to create k8s namespace from file %s", nsFile)
	testNs := nsObj.GetName()

	// Create local OTLP sinks
	// Use distinct ports from other tests to avoid collisions:
	//   metrics: 6317, traces (gateway exporter): 6321, logs: 6323
	metricsConsumer := newMetricsSink()
	gatewayTracesConsumer := newTracesSink()
	logsConsumer := newLogsSink()

	shutdownSink := StartUpSinks(t, ReceiverSinks{
		Metrics: &MetricSinkConfig{
			Consumer: metricsConsumer,
			Ports: &ReceiverPorts{
				Grpc: 6317,
			},
		},
		Traces: &TraceSinkConfig{
			Consumer: gatewayTracesConsumer,
			Ports: &ReceiverPorts{
				Grpc: 6321,
			},
		},
		Logs: &LogSinkConfig{
			Consumer: logsConsumer,
			Ports: &ReceiverPorts{
				Grpc: 6323,
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

	// Also create and delete a simple pod to trigger k8s entity metrics/logs similar to agent test
	podFile := filepath.Join(testDataDir, "pod.yaml")
	buf, err = os.ReadFile(podFile)
	require.NoErrorf(t, err, "failed to read pod object file %s", podFile)
	podObj, err := xk8stest.CreateObject(k8sClient, buf)
	require.NoErrorf(t, err, "failed to create k8s pod from file %s", podFile)
	require.Eventually(t, func() bool {
		pod, err := k8sClient.DynamicClient.Resource(corev1.SchemeGroupVersion.WithResource("pods")).Namespace(testNs).Get(context.Background(), podObj.GetName(), metav1.GetOptions{})
		return err == nil && pod.Object["status"].(map[string]interface{})["phase"] == string(corev1.PodRunning)
	}, time.Minute, time.Second)
	xk8stest.DeleteObject(k8sClient, podObj)

	// Expectations:
	// - Metrics and Logs should be exported directly via OTLP exporters to local sinks
	// - Traces should be exported by the Gateway after tail-sampling to the local traces sink
	waitForLogs(t, 1, logsConsumer)
	waitForMetrics(t, 20, metricsConsumer)
	waitForTraces(t, 10, gatewayTracesConsumer)

	// Verify traces were exported by the gateway by checking resource attribute
	assertTracesHaveGatewayAgentType(t, gatewayTracesConsumer.AllTraces())
}

// new* helpers keep imports concise in the test body
func newMetricsSink() *consumertest.MetricsSink { return new(consumertest.MetricsSink) }
func newTracesSink() *consumertest.TracesSink   { return new(consumertest.TracesSink) }
func newLogsSink() *consumertest.LogsSink       { return new(consumertest.LogsSink) }

// assertTracesHaveGatewayAgentType verifies that at least one ResourceSpans entry
// has cx.agent.type == "gateway", proving spans traversed the gateway pipeline.
func assertTracesHaveGatewayAgentType(t *testing.T, traces []ptrace.Traces) {
	t.Helper()
	found := false
	for _, current := range traces {
		td := ptrace.NewTraces()
		current.CopyTo(td)
		rs := td.ResourceSpans()
		for i := 0; i < rs.Len(); i++ {
			attrs := rs.At(i).Resource().Attributes()
			if hasAttrWithValue(attrs, "cx.agent.type", "gateway") {
				found = true
				break
			}
		}
		if found {
			break
		}
	}
	if !found {
		t.Fatalf("expected traces to have resource attribute cx.agent.type=gateway")
	}
}

func hasAttrWithValue(attrs pcommon.Map, key, expected string) bool {
	if v, ok := attrs.Get(key); ok {
		return v.AsString() == expected
	}
	return false
}
