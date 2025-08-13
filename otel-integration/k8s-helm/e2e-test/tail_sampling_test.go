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
	"go.opentelemetry.io/collector/pdata/pmetric"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// TestE2E_TailSampling validates a tail-sampling setup where:
// 1) The agent sends traces only to the gateway via loadbalancing exporter
// 2) The agent sends metrics and logs directly to OTLP exporters (local sinks)
// 3) The gateway forwards (tail-samples) all traces to a local OTLP traces sink
//
// IMPORTANT: Deploy the chart with test overrides in testdata/values-e2e-tail-sampling.yaml
// so that agent traces use loadbalancing -> gateway, and gateway exports traces to the local sink.
func TestE2E_TailSampling(t *testing.T) {
	// Parity with other e2e tests: ensure host endpoint env matches detector
	require.Equal(t, xk8stest.HostEndpoint(t), os.Getenv("HOSTENDPOINT"), "HostEndpoints does not match env and detected")

	// Kube client for namespace/pod lifecycle helpers
	kubeconfigPath := testKubeConfig
	if kubeConfigFromEnv := os.Getenv(kubeConfigEnvVar); kubeConfigFromEnv != "" {
		kubeconfigPath = kubeConfigFromEnv
	}
	k8sClient, err := xk8stest.NewK8sClient(kubeconfigPath)
	require.NoError(t, err)

	// Dedicated namespace for this test
	testDataDir := filepath.Join("testdata")
	nsFile := filepath.Join(testDataDir, "namespace.yaml")
	buf, err := os.ReadFile(nsFile)
	require.NoErrorf(t, err, "failed to read namespace object file %s", nsFile)
	nsObj, err := xk8stest.CreateObject(k8sClient, buf)
	require.NoErrorf(t, err, "failed to create k8s namespace from file %s", nsFile)

	testNs := nsObj.GetName()

	// Create a short-lived pod to stimulate k8s event/metrics paths (same as agent test)
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

	// Bring up local OTLP sinks
	metricsConsumer := new(consumertest.MetricsSink)
	tracesConsumer := new(consumertest.TracesSink)
	logsConsumer := new(consumertest.LogsSink)

	shutdownSink := StartUpSinks(t, ReceiverSinks{
		Metrics: &MetricSinkConfig{
			Consumer: metricsConsumer,
			Ports: &ReceiverPorts{
				Grpc: 4317,
			},
		},
		Traces: &TraceSinkConfig{
			Consumer: tracesConsumer,
			Ports: &ReceiverPorts{
				Grpc: 4321,
			},
		},
		Logs: &LogSinkConfig{
			Consumer: logsConsumer,
			Ports: &ReceiverPorts{
				Grpc: 4323,
			},
		},
	})
	defer shutdownSink()

	// Start trace traffic via telemetrygen
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
		require.NoErrorf(t, xk8stest.DeleteObject(k8sClient, nsObj), "failed to delete namespace %s", testNs)
		for _, obj := range telemetryGenObjs {
			require.NoErrorf(t, xk8stest.DeleteObject(k8sClient, obj), "failed to delete object %s", obj.GetName())
		}
	})

	// Expect logs/metrics directly from the agent exporters, and traces from the gateway
	waitForLogs(t, 1, logsConsumer)
	waitForMetrics(t, 20, metricsConsumer)
	waitForTraces(t, 10, tracesConsumer)

	// Assert exporter usage on agent self-metrics: traces via loadbalancing; logs/metrics via OTLP exporters
	assertAgentExporterRouting(t, metricsConsumer.AllMetrics())
	// Assert gateway exports spans via OTLP traces exporter (tail-sampling pass-through)
	assertGatewayExportsTraces(t, metricsConsumer.AllMetrics())
}

// assertAgentExporterRouting checks agent self-metrics for expected exporter labels
// - otelcol_exporter_sent_spans: exporter=="loadbalancing" and NOT exporter=="otlp/traces"
// - otelcol_exporter_sent_metric_points: exporter=="otlp/metrics"
// - otelcol_exporter_sent_log_records: exporter=="otlp/logs"
func assertAgentExporterRouting(t *testing.T, all []pmetric.Metrics) {
	foundSpansViaLB := false
	foundSpansViaDirectOTLP := false
	foundMetricsDirect := false
	foundLogsDirect := false

	for _, m := range all {
		copy := pmetric.NewMetrics()
		m.CopyTo(copy)
		rms := copy.ResourceMetrics()
		for i := 0; i < rms.Len(); i++ {
			// Only consider self-metrics emitted by the agent
			res := rms.At(i).Resource()
			if v, ok := res.Attributes().Get("cx.agent.type"); !ok || v.AsString() != "agent" {
				continue
			}
			sms := rms.At(i).ScopeMetrics()
			for j := 0; j < sms.Len(); j++ {
				ms := sms.At(j).Metrics()
				for k := 0; k < ms.Len(); k++ {
					metric := ms.At(k)
					name := metric.Name()
					switch metric.Type() {
					case pmetric.MetricTypeSum:
						dps := metric.Sum().DataPoints()
						for x := 0; x < dps.Len(); x++ {
							dp := dps.At(x)
							exporter := attrString(dp.Attributes(), "exporter")
							if name == "otelcol_exporter_sent_spans" {
								if exporter == "loadbalancing" {
									foundSpansViaLB = true
								}
								if exporter == "otlp/traces" {
									foundSpansViaDirectOTLP = true
								}
							}
							if name == "otelcol_exporter_sent_metric_points" && exporter == "otlp/metrics" {
								foundMetricsDirect = true
							}
							if name == "otelcol_exporter_sent_log_records" && exporter == "otlp/logs" {
								foundLogsDirect = true
							}
						}
					case pmetric.MetricTypeGauge:
						dps := metric.Gauge().DataPoints()
						for x := 0; x < dps.Len(); x++ {
							dp := dps.At(x)
							exporter := attrString(dp.Attributes(), "exporter")
							if name == "otelcol_exporter_sent_spans" {
								if exporter == "loadbalancing" {
									foundSpansViaLB = true
								}
								if exporter == "otlp/traces" {
									foundSpansViaDirectOTLP = true
								}
							}
							if name == "otelcol_exporter_sent_metric_points" && exporter == "otlp/metrics" {
								foundMetricsDirect = true
							}
							if name == "otelcol_exporter_sent_log_records" && exporter == "otlp/logs" {
								foundLogsDirect = true
							}
						}
					}
				}
			}
		}
	}

	// Traces must be routed via loadbalancing exporter and not direct OTLP
	require.True(t, foundSpansViaLB, "agent did not report spans via loadbalancing exporter")
	require.False(t, foundSpansViaDirectOTLP, "agent should not send spans via direct OTLP exporter")
	// Logs and metrics should be exported directly via OTLP exporters
	require.True(t, foundMetricsDirect, "agent did not report metrics via OTLP metrics exporter")
	require.True(t, foundLogsDirect, "agent did not report logs via OTLP logs exporter")
}

func attrString(m pcommon.Map, key string) string {
	if v, ok := m.Get(key); ok {
		return v.AsString()
	}
	return ""
}

// assertGatewayExportsTraces verifies that the gateway exported spans via the configured OTLP exporter.
func assertGatewayExportsTraces(t *testing.T, all []pmetric.Metrics) {
	exportedViaOtlp := false
	for _, m := range all {
		copy := pmetric.NewMetrics()
		m.CopyTo(copy)
		rms := copy.ResourceMetrics()
		for i := 0; i < rms.Len(); i++ {
			res := rms.At(i).Resource()
			// Consider any collector resource that is not the agent
			if v, ok := res.Attributes().Get("cx.agent.type"); ok && v.AsString() == "agent" {
				continue
			}
			sms := rms.At(i).ScopeMetrics()
			for j := 0; j < sms.Len(); j++ {
				ms := sms.At(j).Metrics()
				for k := 0; k < ms.Len(); k++ {
					metric := ms.At(k)
					if metric.Name() != "otelcol_exporter_sent_spans" {
						continue
					}
					switch metric.Type() {
					case pmetric.MetricTypeSum:
						dps := metric.Sum().DataPoints()
						for x := 0; x < dps.Len(); x++ {
							if attrString(dps.At(x).Attributes(), "exporter") == "otlp/traces" {
								exportedViaOtlp = true
							}
						}
					case pmetric.MetricTypeGauge:
						dps := metric.Gauge().DataPoints()
						for x := 0; x < dps.Len(); x++ {
							if attrString(dps.At(x).Attributes(), "exporter") == "otlp/traces" {
								exportedViaOtlp = true
							}
						}
					}
				}
			}
		}
	}
	require.True(t, exportedViaOtlp, "gateway did not report spans via otlp/traces exporter")
}
