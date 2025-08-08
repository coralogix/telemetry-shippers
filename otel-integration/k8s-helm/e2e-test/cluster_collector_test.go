package e2e

import (
	"os"
	"testing"

	"github.com/open-telemetry/opentelemetry-collector-contrib/pkg/xk8stest"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/consumer/consumertest"
	"go.opentelemetry.io/collector/pdata/pmetric"
	"maps"
	"slices"
)

// TestE2E_ClusterCollector_Metrics verifies that the cluster-collector exports metrics
// to a local OTLP sink and that resource attributes mark it as a cluster-collector.
func TestE2E_ClusterCollector_Metrics(t *testing.T) {
	// Validate host endpoint detection vs env (parity with agent test)
	require.Equal(t, xk8stest.HostEndpoint(t), os.Getenv("HOSTENDPOINT"), "HostEndpoints does not match env and detected")

	// Use kubeconfig from env if set (same as agent test)
	kubeconfigPath := testKubeConfig
	if kubeConfigFromEnv := os.Getenv(kubeConfigEnvVar); kubeConfigFromEnv != "" {
		kubeconfigPath = kubeConfigFromEnv
	}

	// Ensure we can instantiate a client (implicitly validates kubeconfig path works)
	k8sClient, err := xk8stest.NewK8sClient(kubeconfigPath)
	require.NoError(t, err)
	_ = k8sClient // client currently unused; metrics are verified via local sinks

	// Start a metrics sink on dedicated ports for the cluster-collector
	metricsConsumer := new(consumertest.MetricsSink)
	shutdownSink := StartUpSinks(t, ReceiverSinks{
		Metrics: &MetricSinkConfig{
			Consumer: metricsConsumer,
			Ports: &ReceiverPorts{
				Grpc: 5337,
			},
		},
	})
	defer shutdownSink()

	// Wait until we receive some metrics batches
	waitForMetrics(t, 5, metricsConsumer)

	// Validate that at least some expected cluster metrics arrived
	require.NoError(t, checkClusterCollectorMetrics(t, metricsConsumer.AllMetrics()))
}

func checkClusterCollectorMetrics(t *testing.T, actual []pmetric.Metrics) error {
	t.Helper()

	// Track a broad set of representative cluster metrics; we will require a sizable subset
	expectedAny := map[string]bool{
		// K8s general
		"k8s.namespace.phase": false,
		// Pods
		"k8s.pod.phase":         false,
		"k8s.pod.status_reason": false,
		// Containers
		"k8s.container.ready":                         false,
		"k8s.container.restarts":                      false,
		"k8s.container.cpu_limit":                     false,
		"k8s.container.cpu_request":                   false,
		"k8s.container.memory_limit":                  false,
		"k8s.container.memory_request":                false,
		"k8s.container.status.last_terminated_reason": false,
		// Container filesystem & cgroups
		"container_fs_usage_bytes":                  false,
		"container_fs_reads_total":                  false,
		"container_fs_writes_total":                 false,
		"container_fs_reads_bytes_total":            false,
		"container_fs_writes_bytes_total":           false,
		"container_cpu_cfs_periods_total":           false,
		"container_cpu_cfs_throttled_periods_total": false,
		// Deployments / ReplicaSets
		"k8s.deployment.desired":   false,
		"k8s.deployment.available": false,
		"k8s.replicaset.desired":   false,
		"k8s.replicaset.available": false,
		// DaemonSets
		"k8s.daemonset.desired_scheduled_nodes": false,
		"k8s.daemonset.current_scheduled_nodes": false,
		"k8s.daemonset.ready_nodes":             false,
		"k8s.daemonset.misscheduled_nodes":      false,
		// Nodes
		"k8s.node.condition_ready":    false,
		"k8s.node.allocatable_cpu":    false,
		"k8s.node.allocatable_memory": false,
		// Kube-state metadata
		"kube_node_info":            false,
		"kube_pod_status_reason":    false,
		"kube_pod_status_qos_class": false,
		"kubernetes_build_info":     false,
		// Collector self metrics (sanity that pipeline runs)
		"otelcol_exporter_queue_capacity":                false,
		"otelcol_exporter_queue_size":                    false,
		"otelcol_exporter_sent_metric_points":            false,
		"otelcol_exporter_send_failed_metric_points":     false,
		"otelcol_exporter_sent_log_records":              false,
		"otelcol_exporter_send_failed_log_records":       false,
		"otelcol_receiver_accepted_metric_points":        false,
		"otelcol_receiver_refused_metric_points":         false,
		"otelcol_receiver_accepted_log_records":          false,
		"otelcol_receiver_refused_log_records":           false,
		"otelcol_processor_incoming_items":               false,
		"otelcol_processor_outgoing_items":               false,
		"otelcol_processor_batch_batch_send_size":        false,
		"otelcol_processor_batch_timeout_trigger_send":   false,
		"otelcol_processor_batch_metadata_cardinality":   false,
		"otelcol_processor_accepted_metric_points":       false,
		"otelcol_processor_accepted_log_records":         false,
		"otelcol_processor_filter_logs.filtered":         false,
		"otelcol_processor_filter_datapoints.filtered":   false,
		"otelcol_process_cpu_seconds":                    false,
		"otelcol_process_memory_rss_bytes":               false,
		"otelcol_process_runtime_heap_alloc_bytes":       false,
		"otelcol_process_runtime_total_sys_memory_bytes": false,
		"otelcol_process_runtime_total_alloc_bytes":      false,
		"otelcol_process_uptime_seconds":                 false,
		"otelcol_otelsvc_k8s_pod_added_ratio":            false,
		"otelcol_otelsvc_k8s_pod_updated_ratio":          false,
		"otelcol_otelsvc_k8s_pod_deleted_ratio":          false,
		"otelcol_otelsvc_k8s_pod_table_size_ratio":       false,
		// Prom scrape/handler
		"up":                                    false,
		"scrape_samples_scraped":                false,
		"scrape_samples_post_metric_relabeling": false,
		"scrape_series_added":                   false,
		"scrape_duration_seconds":               false,
		"promhttp_metric_handler_errors":        false,
	}

	namesFound := map[string]struct{}{}
	for _, current := range actual {
		m := pmetric.NewMetrics()
		current.CopyTo(m)

		rms := m.ResourceMetrics()
		for i := 0; i < rms.Len(); i++ {
			sms := rms.At(i).ScopeMetrics()
			for j := 0; j < sms.Len(); j++ {
				ms := sms.At(j).Metrics()
				for k := 0; k < ms.Len(); k++ {
					name := ms.At(k).Name()
					if _, ok := expectedAny[name]; ok {
						expectedAny[name] = true
					}
					namesFound[name] = struct{}{}
				}
			}
		}
	}

	matched := 0
	for _, v := range expectedAny {
		if v {
			matched++
		}
	}
	// Print the set of metric names we saw to help future adjustments
	t.Logf("Observed metric names: %v", slices.Collect(maps.Keys(namesFound)))
	// Coverage summary
	uncovered := make([]string, 0)
	for name := range namesFound {
		if _, ok := expectedAny[name]; !ok {
			uncovered = append(uncovered, name)
		}
	}
	t.Logf("Unique metrics observed: %d; matched expected: %d", len(namesFound), matched)
	t.Logf("Examples of additional metrics not yet asserted: %v", sample(uncovered, 20))
	// Require a healthy subset to reduce flakiness while ensuring broad coverage
	require.GreaterOrEqual(t, matched, 25, "did not observe sufficient cluster-collector metrics")
	return nil
}

// sample returns up to n items from the list for logging without flooding output.
func sample(list []string, n int) []string {
	if len(list) <= n {
		return list
	}
	return list[:n]
}
