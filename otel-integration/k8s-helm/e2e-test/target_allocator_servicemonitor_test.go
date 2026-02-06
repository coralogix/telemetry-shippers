package e2e

import (
	"context"
	"fmt"
	"os"
	"sort"
	"strings"
	"testing"
	"time"

	"github.com/open-telemetry/opentelemetry-collector-contrib/pkg/xk8stest"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/consumer/consumertest"
	"go.opentelemetry.io/collector/pdata/pcommon"
	"go.opentelemetry.io/collector/pdata/pmetric"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

const (
	targetAllocatorServiceMonitorNamespace = "monitoring"
	targetAllocatorServiceMonitorKeyword   = "kubelet"
	targetAllocatorServiceMonitorJobPrefix = "serviceMonitor/"
)

// TestE2E_TargetAllocator_ServiceMonitorMetrics validates that enabling Target Allocator
// with Prometheus CR discovery results in ServiceMonitor-derived metrics being exported.
//
// The run-all.sh harness installs a lightweight kube-prometheus-stack for this test so
// ServiceMonitor CRDs/resources exist (including kubelet ServiceMonitor).
func TestE2E_TargetAllocator_ServiceMonitorMetrics(t *testing.T) {
	if os.Getenv("RUN_TARGET_ALLOCATOR_E2E") != "1" {
		t.Skip("skipping target allocator ServiceMonitor E2E; set RUN_TARGET_ALLOCATOR_E2E=1 to enable")
	}

	require.Equal(t, xk8stest.HostEndpoint(t), os.Getenv("HOSTENDPOINT"), "HostEndpoints does not match env and detected")

	kubeconfigPath := testKubeConfig
	if kubeConfigFromEnv := os.Getenv(kubeConfigEnvVar); kubeConfigFromEnv != "" {
		kubeconfigPath = kubeConfigFromEnv
	}

	k8sClient, err := xk8stest.NewK8sClient(kubeconfigPath)
	require.NoError(t, err)

	waitForKubeletServiceMonitor(t, k8sClient)

	metricsConsumer := new(consumertest.MetricsSink)
	shutdownSink := StartUpSinks(t, ReceiverSinks{
		Metrics: &MetricSinkConfig{
			Consumer: metricsConsumer,
			Ports: &ReceiverPorts{
				Grpc: 7337,
			},
		},
	})
	defer shutdownSink()

	waitForMetrics(t, 5, metricsConsumer)
	require.NoError(t, checkTargetAllocatorServiceMonitorMetrics(metricsConsumer.AllMetrics()))
}

func waitForKubeletServiceMonitor(t *testing.T, k8sClient *xk8stest.K8sClient) {
	t.Helper()

	svcMonitorGVR := schema.GroupVersionResource{
		Group:    "monitoring.coreos.com",
		Version:  "v1",
		Resource: "servicemonitors",
	}

	require.Eventually(t, func() bool {
		list, err := k8sClient.DynamicClient.Resource(svcMonitorGVR).Namespace(targetAllocatorServiceMonitorNamespace).
			List(context.Background(), metav1.ListOptions{})
		if err != nil {
			t.Logf("waiting for ServiceMonitor CRs: %v", err)
			return false
		}
		for _, item := range list.Items {
			if strings.Contains(item.GetName(), targetAllocatorServiceMonitorKeyword) {
				return true
			}
		}
		return false
	}, 3*time.Minute, 2*time.Second, "kubelet ServiceMonitor was not found")
}

func checkTargetAllocatorServiceMonitorMetrics(actual []pmetric.Metrics) error {
	observedServices := map[string]struct{}{}
	observedJobs := map[string]struct{}{}
	observedMetricNames := map[string]struct{}{}

	foundKubeletServiceMetric := false
	foundKubeletServiceMonitorJob := false
	foundKubeletPrometheusMetric := false
	foundScrapeSamplesMetric := false

	for _, batch := range actual {
		rms := batch.ResourceMetrics()
		for i := 0; i < rms.Len(); i++ {
			sms := rms.At(i).ScopeMetrics()
			for j := 0; j < sms.Len(); j++ {
				metrics := sms.At(j).Metrics()
				for k := 0; k < metrics.Len(); k++ {
					metric := metrics.At(k)
					metricName := metric.Name()
					observedMetricNames[metricName] = struct{}{}
					if isKubeletPrometheusMetric(metricName) {
						foundKubeletPrometheusMetric = true
					}
					if metricName == "scrape_samples_scraped" {
						foundScrapeSamplesMetric = true
					}

					forEachMetricDataPoint(metric, func(attrs pcommon.Map) {
						if jobAttr, ok := attrs.Get("job"); ok {
							jobName := jobAttr.Str()
							observedJobs[jobName] = struct{}{}
							if strings.Contains(jobName, targetAllocatorServiceMonitorJobPrefix) &&
								strings.Contains(jobName, targetAllocatorServiceMonitorKeyword) {
								foundKubeletServiceMonitorJob = true
							}
						}

						serviceAttr, ok := attrs.Get("service")
						if !ok {
							return
						}
						serviceName := serviceAttr.Str()
						observedServices[serviceName] = struct{}{}
						if strings.Contains(serviceName, targetAllocatorServiceMonitorKeyword) {
							foundKubeletServiceMetric = true
						}
					})
				}
			}
		}
	}

	// Primary assertions:
	// 1) Job label indicates ServiceMonitor-based kubelet scrape.
	// 2) Legacy fallback where service attribute includes kubelet.
	// 3) Fallback for environments where labels are transformed:
	//    kubelet Prometheus metric names + scrape_samples_scraped observed.
	if !foundKubeletServiceMonitorJob && !foundKubeletServiceMetric && !(foundKubeletPrometheusMetric && foundScrapeSamplesMetric) {
		return fmt.Errorf(
			"did not observe ServiceMonitor-derived kubelet metrics; observed services=%v observed jobs=%v observed_metric_names=%v",
			sortedMapKeys(observedServices),
			sortedMapKeys(observedJobs),
			sortedMapKeys(observedMetricNames),
		)
	}

	return nil
}

func isKubeletPrometheusMetric(metricName string) bool {
	// Kubelet/cAdvisor Prometheus metrics discovered via ServiceMonitor typically
	// use snake_case names (for example: container_cpu_cfs_periods_total,
	// container_fs_reads_bytes_total). This differentiates them from kubeletstats
	// receiver metrics that are dot-delimited (for example: container.cpu.time).
	if strings.HasPrefix(metricName, "container_") {
		return true
	}

	switch metricName {
	case "container_cpu_cfs_periods_total",
		"container_cpu_cfs_throttled_periods_total",
		"container_fs_reads_bytes_total",
		"container_fs_reads_total",
		"container_fs_writes_bytes_total",
		"container_fs_writes_total",
		"container_fs_usage_bytes":
		return true
	default:
		return false
	}
}

func forEachMetricDataPoint(metric pmetric.Metric, fn func(attrs pcommon.Map)) {
	switch metric.Type() {
	case pmetric.MetricTypeGauge:
		dps := metric.Gauge().DataPoints()
		for i := 0; i < dps.Len(); i++ {
			fn(dps.At(i).Attributes())
		}
	case pmetric.MetricTypeSum:
		dps := metric.Sum().DataPoints()
		for i := 0; i < dps.Len(); i++ {
			fn(dps.At(i).Attributes())
		}
	case pmetric.MetricTypeHistogram:
		dps := metric.Histogram().DataPoints()
		for i := 0; i < dps.Len(); i++ {
			fn(dps.At(i).Attributes())
		}
	case pmetric.MetricTypeExponentialHistogram:
		dps := metric.ExponentialHistogram().DataPoints()
		for i := 0; i < dps.Len(); i++ {
			fn(dps.At(i).Attributes())
		}
	case pmetric.MetricTypeSummary:
		dps := metric.Summary().DataPoints()
		for i := 0; i < dps.Len(); i++ {
			fn(dps.At(i).Attributes())
		}
	}
}

func sortedMapKeys(m map[string]struct{}) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}
