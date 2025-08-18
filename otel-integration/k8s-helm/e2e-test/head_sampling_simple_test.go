package e2e

import (
    "context"
    "os"
    "path/filepath"
    "strings"
    "testing"
    "time"

    "github.com/google/uuid"
    "github.com/open-telemetry/opentelemetry-collector-contrib/pkg/xk8stest"
    "github.com/stretchr/testify/require"
    "go.opentelemetry.io/collector/consumer/consumertest"
    corev1 "k8s.io/api/core/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// TestE2E_HeadSampling_Simple validates that with probabilistic head sampling at 0%,
// no spans are exported to the local OTLP sink.
//
// Prerequisites (helm install example):
//
//	helm upgrade --install otel-integration-agent-e2e . \
//	  --set global.clusterName="otel-integration-agent-e2e" \
//	  --set global.domain="coralogix.com" \
//	  --set global.hostedEndpoint=$HOSTENDPOINT \
//	  -f ./values.yaml \
//	  -f ./e2e-test/testdata/values-e2e-head-sampling.yaml
//
func TestE2E_HeadSampling_Simple(t *testing.T) {
    if os.Getenv("RUN_HEAD_SAMPLING_E2E") != "1" {
        t.Skip("skipping head-sampling E2E; set RUN_HEAD_SAMPLING_E2E=1 to enable")
    }

    require.Equal(t, xk8stest.HostEndpoint(t), os.Getenv("HOSTENDPOINT"), "HostEndpoints does not match env and detected")

    testDataDir := filepath.Join("testdata")

    kubeconfigPath := testKubeConfig
    if kubeConfigFromEnv := os.Getenv(kubeConfigEnvVar); kubeConfigFromEnv != "" {
        kubeconfigPath = kubeConfigFromEnv
    }

    k8sClient, err := xk8stest.NewK8sClient(kubeconfigPath)
    require.NoError(t, err)

    nsFile := filepath.Join(testDataDir, "namespace.yaml")
    buf, err := os.ReadFile(nsFile)
    require.NoErrorf(t, err, "failed to read namespace object file %s", nsFile)
    nsObj, err := xk8stest.CreateObject(k8sClient, buf)
    if err != nil {
        if strings.Contains(err.Error(), "already exists") {
            existing, getErr := k8sClient.DynamicClient.Resource(corev1.SchemeGroupVersion.WithResource("namespaces")).Get(context.Background(), "e2e", metav1.GetOptions{})
            require.NoError(t, getErr)
            nsObj = existing
        } else {
            require.NoErrorf(t, err, "failed to create k8s namespace from file %s", nsFile)
        }
    }
    _ = nsObj.GetName()

    // Local OTLP sink for traces on port 7321 (matches override file)
    tracesConsumer := new(consumertest.TracesSink)
    shutdownSink := StartUpSinks(t, ReceiverSinks{
        Traces: &TraceSinkConfig{
            Consumer: tracesConsumer,
            Ports: &ReceiverPorts{
                Grpc: 7321,
            },
        },
    })
    defer shutdownSink()

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

    // Assert that no traces are received for a reasonable period
    deadline := time.Now().Add(30 * time.Second)
    for time.Now().Before(deadline) {
        if len(tracesConsumer.AllTraces()) > 0 {
            t.Fatalf("expected no traces with head sampling at 0%%, but some were received")
        }
        time.Sleep(1 * time.Second)
    }
}


