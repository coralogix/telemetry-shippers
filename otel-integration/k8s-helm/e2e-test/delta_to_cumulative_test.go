package e2e

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/open-telemetry/opentelemetry-collector-contrib/pkg/xk8stest"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/consumer/consumertest"
	"go.opentelemetry.io/collector/pdata/pcommon"
	"go.opentelemetry.io/collector/pdata/pmetric"
	colmetricspb "go.opentelemetry.io/proto/otlp/collector/metrics/v1"
	commonpb "go.opentelemetry.io/proto/otlp/common/v1"
	metricspb "go.opentelemetry.io/proto/otlp/metrics/v1"
	resourcepb "go.opentelemetry.io/proto/otlp/resource/v1"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

const (
	deltaMetricEmitTimeout         = 45 * time.Second
	deltaMetricWaitTimeout         = 3 * time.Minute
	deltaMetricName                = "delta_to_cumulative_e2e_counter"
	deltaMetricAttrKey             = "delta.to.cumulative.test.id"
	collectorDeltaDatapointsMetric = "otelcol_deltatocumulative_datapoints"
)

func TestE2E_DeltaToCumulativePreset(t *testing.T) {
	require.Equal(t, xk8stest.HostEndpoint(t), os.Getenv("HOSTENDPOINT"), "HostEndpoints does not match env and detected")

	kubeconfigPath := testKubeConfig
	if kubeConfigFromEnv := os.Getenv(kubeConfigEnvVar); kubeConfigFromEnv != "" {
		kubeconfigPath = kubeConfigFromEnv
	}

	k8sClient, err := xk8stest.NewK8sClient(kubeconfigPath)
	require.NoError(t, err)

	metricsConsumer := new(consumertest.MetricsSink)
	shutdownSinks := StartUpSinks(t, ReceiverSinks{
		Metrics: &MetricSinkConfig{
			Consumer: metricsConsumer,
			Ports: &ReceiverPorts{
				Grpc: 4317,
			},
		},
	})
	defer shutdownSinks()

	localPort, stopPF := startAgentOTLPPortForward(t, k8sClient, kubeconfigPath, 4317)
	defer stopPF()

	serviceName := fmt.Sprintf("delta-cumulative-e2e-%s", uuid.NewString()[:8])
	testID := uuid.NewString()
	endpoint := fmt.Sprintf("127.0.0.1:%d", localPort)
	deltaValues := []float64{5, 7, 4}
	expectedTotal := sum(deltaValues)
	startTime := time.Now().Add(-2 * time.Second)
	expectedStart := pcommon.NewTimestampFromTime(startTime)

	ctx, cancel := context.WithTimeout(context.Background(), deltaMetricEmitTimeout)
	defer cancel()

	t.Logf("Emitting delta metrics via endpoint=%s service=%s", endpoint, serviceName)
	require.NoError(t, emitDeltaMetrics(ctx, endpoint, serviceName, testID, startTime, deltaValues))
	t.Log("Delta metrics emitted, waiting for cumulative export")

	waitForCumulativeMetric(t, metricsConsumer, serviceName, testID, expectedStart, expectedTotal)
	waitForCollectorMetric(t, metricsConsumer, collectorDeltaDatapointsMetric)
	t.Log("Delta-to-cumulative conversion verified successfully")
	// Allow stale delta streams to expire before other tests assert on exported metrics.
	time.Sleep(3 * time.Second)
}

func emitDeltaMetrics(ctx context.Context, endpoint, serviceName, testID string, startTime time.Time, deltaValues []float64) error {
	conn, err := grpc.NewClient(
		endpoint,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		return fmt.Errorf("create OTLP client: %w", err)
	}
	defer conn.Close()

	client := colmetricspb.NewMetricsServiceClient(conn)
	currentStart := startTime

	for idx, value := range deltaValues {
		currentEnd := currentStart.Add(time.Second)
		req := buildDeltaMetricsRequest(serviceName, testID, currentStart, currentEnd, value)
		if _, err := client.Export(ctx, req); err != nil {
			return fmt.Errorf("export delta #%d: %w", idx+1, err)
		}
		currentStart = currentEnd
		// Give the collector a moment between exports so the processor can flush state deterministically.
		time.Sleep(250 * time.Millisecond)
	}

	return nil
}

func buildDeltaMetricsRequest(serviceName, testID string, startTime, endTime time.Time, value float64) *colmetricspb.ExportMetricsServiceRequest {
	return &colmetricspb.ExportMetricsServiceRequest{
		ResourceMetrics: []*metricspb.ResourceMetrics{
			{
				Resource: &resourcepb.Resource{
					Attributes: []*commonpb.KeyValue{
						stringKeyValue(serviceNameAttribute, serviceName),
					},
				},
				ScopeMetrics: []*metricspb.ScopeMetrics{
					{
						Scope: &commonpb.InstrumentationScope{Name: "delta-to-cumulative-e2e"},
						Metrics: []*metricspb.Metric{
							{
								Name: deltaMetricName,
								Data: &metricspb.Metric_Sum{
									Sum: &metricspb.Sum{
										AggregationTemporality: metricspb.AggregationTemporality_AGGREGATION_TEMPORALITY_DELTA,
										IsMonotonic:            true,
										DataPoints: []*metricspb.NumberDataPoint{
											{
												StartTimeUnixNano: uint64(startTime.UnixNano()),
												TimeUnixNano:      uint64(endTime.UnixNano()),
												Value: &metricspb.NumberDataPoint_AsDouble{
													AsDouble: value,
												},
												Attributes: []*commonpb.KeyValue{
													stringKeyValue(deltaMetricAttrKey, testID),
												},
											},
										},
									},
								},
							},
						},
					},
				},
			},
		},
	}
}

func waitForCumulativeMetric(t *testing.T, sink *consumertest.MetricsSink, serviceName, testID string, expectedStart pcommon.Timestamp, expectedTotal float64) {
	t.Helper()

	require.Eventuallyf(t, func() bool {
		return hasCumulativeSample(sink.AllMetrics(), serviceName, testID, expectedStart, expectedTotal)
	}, deltaMetricWaitTimeout, 2*time.Second, "did not observe cumulative metric for service=%s testID=%s", serviceName, testID)
}

func waitForCollectorMetric(t *testing.T, sink *consumertest.MetricsSink, metricName string) {
	t.Helper()

	require.Eventuallyf(t, func() bool {
		return collectorMetricExists(sink.AllMetrics(), metricName)
	}, deltaMetricWaitTimeout, 2*time.Second, "did not observe collector metric %s", metricName)
}

func hasCumulativeSample(metrics []pmetric.Metrics, serviceName, testID string, expectedStart pcommon.Timestamp, expectedTotal float64) bool {
	for _, current := range metrics {
		rms := current.ResourceMetrics()
		for i := 0; i < rms.Len(); i++ {
			rm := rms.At(i)
			resourceServiceName, ok := rm.Resource().Attributes().Get(serviceNameAttribute)
			if !ok || resourceServiceName.AsString() != serviceName {
				continue
			}

			scopeMetrics := rm.ScopeMetrics()
			for j := 0; j < scopeMetrics.Len(); j++ {
				metricsSlice := scopeMetrics.At(j).Metrics()
				for k := 0; k < metricsSlice.Len(); k++ {
					metric := metricsSlice.At(k)
					if metric.Name() != deltaMetricName || metric.Type() != pmetric.MetricTypeSum {
						continue
					}

					sum := metric.Sum()
					if sum.AggregationTemporality() != pmetric.AggregationTemporalityCumulative || !sum.IsMonotonic() {
						continue
					}

					dps := sum.DataPoints()
					for l := 0; l < dps.Len(); l++ {
						dp := dps.At(l)
						attr, hasAttr := dp.Attributes().Get(deltaMetricAttrKey)
						if !hasAttr || attr.AsString() != testID {
							continue
						}
						if dp.StartTimestamp() != expectedStart {
							continue
						}
						value := numberDataPointValue(dp)
						if value >= expectedTotal {
							return true
						}
					}
				}
			}
		}
	}
	return false
}

func collectorMetricExists(metrics []pmetric.Metrics, metricName string) bool {
	for _, current := range metrics {
		rms := current.ResourceMetrics()
		for i := 0; i < rms.Len(); i++ {
			scopeMetrics := rms.At(i).ScopeMetrics()
			for j := 0; j < scopeMetrics.Len(); j++ {
				metricSlice := scopeMetrics.At(j).Metrics()
				for k := 0; k < metricSlice.Len(); k++ {
					if metricSlice.At(k).Name() == metricName {
						return true
					}
				}
			}
		}
	}
	return false
}

func sum(values []float64) float64 {
	var total float64
	for _, v := range values {
		total += v
	}
	return total
}

func numberDataPointValue(dp pmetric.NumberDataPoint) float64 {
	if dp.ValueType() == pmetric.NumberDataPointValueTypeDouble {
		return dp.DoubleValue()
	}
	return float64(dp.IntValue())
}

func stringKeyValue(key, value string) *commonpb.KeyValue {
	return &commonpb.KeyValue{
		Key: key,
		Value: &commonpb.AnyValue{
			Value: &commonpb.AnyValue_StringValue{
				StringValue: value,
			},
		},
	}
}
