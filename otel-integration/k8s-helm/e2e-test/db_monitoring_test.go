package e2e

import (
	"bytes"
	"context"
	"io"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/open-telemetry/opentelemetry-collector-contrib/pkg/xk8stest"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/consumer/consumertest"
	"go.opentelemetry.io/collector/pdata/pcommon"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apimachinery/pkg/util/yaml"
)

// TestE2E_DBMonitoring collects real PostgreSQL telemetry through the dedicated Deployment.
func TestE2E_DBMonitoring(t *testing.T) {
	require.NotEmpty(t, os.Getenv("HOSTENDPOINT"))
	kubeconfigPath := testKubeConfig
	if value := os.Getenv(kubeConfigEnvVar); value != "" {
		kubeconfigPath = value
	}
	client, err := xk8stest.NewK8sClient(kubeconfigPath)
	require.NoError(t, err)

	deployment, err := client.DynamicClient.Resource(schema.GroupVersionResource{
		Group: "apps", Version: "v1", Resource: "deployments",
	}).Namespace("default").Get(context.Background(), "coralogix-opentelemetry-db-monitoring", metav1.GetOptions{})
	require.NoError(t, err)
	replicas, _, err := unstructured.NestedInt64(deployment.Object, "spec", "replicas")
	require.NoError(t, err)
	require.EqualValues(t, 1, replicas)
	strategy, _, err := unstructured.NestedString(deployment.Object, "spec", "strategy", "type")
	require.NoError(t, err)
	require.Equal(t, "Recreate", strategy)
	hostNetwork, _, err := unstructured.NestedBool(deployment.Object, "spec", "template", "spec", "hostNetwork")
	require.NoError(t, err)
	require.False(t, hostNetwork)
	containers, _, err := unstructured.NestedSlice(deployment.Object, "spec", "template", "spec", "containers")
	require.NoError(t, err)
	for _, container := range containers {
		ports, _, err := unstructured.NestedSlice(container.(map[string]any), "ports")
		require.NoError(t, err)
		require.Empty(t, ports, "DB collector must not expose OTLP or host ports")
	}
	_, err = client.DynamicClient.Resource(schema.GroupVersionResource{
		Version: "v1", Resource: "services",
	}).Namespace("default").Get(context.Background(), deployment.GetName(), metav1.GetOptions{})
	require.True(t, apierrors.IsNotFound(err), "DB collector must not create a Service: %v", err)

	metrics := new(consumertest.MetricsSink)
	logs := new(consumertest.LogsSink)
	shutdown := StartUpSinks(t, ReceiverSinks{
		Metrics: &MetricSinkConfig{Consumer: metrics, Ports: &ReceiverPorts{Grpc: 5347}},
		Logs:    &LogSinkConfig{Consumer: logs, Ports: &ReceiverPorts{Grpc: 5349}},
	})
	defer shutdown()

	manifest, err := os.ReadFile(filepath.Join("testdata", "manifests-e2e-db-monitoring.yaml"))
	require.NoError(t, err)
	decoder := yaml.NewYAMLOrJSONDecoder(bytes.NewReader(manifest), 4096)
	for {
		var object unstructured.Unstructured
		if err := decoder.Decode(&object); err == io.EOF {
			break
		} else {
			require.NoError(t, err)
		}
		buf, err := object.MarshalJSON()
		require.NoError(t, err)
		created, err := xk8stest.CreateObject(client, buf)
		require.NoError(t, err)
		t.Cleanup(func() { require.NoError(t, xk8stest.DeleteObject(client, created)) })
	}

	wantMetrics := []string{"postgresql.backends", "postgresql.database.xid_age", "postgresql.table.vacuum.age"}
	wantEvents := []string{"db.server.query_sample", "db.server.top_query", "db.instance", "db.schema"}
	foundMetrics := map[string]bool{}
	foundEvents := map[string]bool{}
	foundTable := false
	require.Eventually(t, func() bool {
		for _, batch := range metrics.AllMetrics() {
			for i := 0; i < batch.ResourceMetrics().Len(); i++ {
				rm := batch.ResourceMetrics().At(i)
				if _, ok := rm.Resource().Attributes().Get("cx.db.instance.id"); !ok {
					continue // Collector self metrics have a separate resource.
				}
				checkDBMonitoringResource(t, rm.Resource().Attributes())
				for j := 0; j < rm.ScopeMetrics().Len(); j++ {
					ms := rm.ScopeMetrics().At(j).Metrics()
					for k := 0; k < ms.Len(); k++ {
						foundMetrics[ms.At(k).Name()] = true
						if ms.At(k).Name() == "postgresql.table.vacuum.age" {
							forEachMetricDataPoint(ms.At(k), func(attrs pcommon.Map) {
								table, _ := attrs.Get("db.collection.name")
								if table.Str() == "widgets" {
									foundTable = true
								}
							})
						}
					}
				}
			}
		}
		for _, batch := range logs.AllLogs() {
			for i := 0; i < batch.ResourceLogs().Len(); i++ {
				rl := batch.ResourceLogs().At(i)
				checkDBMonitoringResource(t, rl.Resource().Attributes())
				for j := 0; j < rl.ScopeLogs().Len(); j++ {
					records := rl.ScopeLogs().At(j).LogRecords()
					for k := 0; k < records.Len(); k++ {
						record := records.At(k)
						if event, ok := record.Attributes().Get("event.name"); ok {
							foundEvents[event.Str()] = true
							for _, key := range []string{"user.name", "postgresql.rolname"} {
								user, _ := record.Attributes().Get(key)
								require.NotEqual(t, "otel", user.Str(), "monitoring queries must be excluded")
							}
						}
						if entity, ok := record.Attributes().Get("otel.entity.type"); ok {
							foundEvents[entity.Str()] = true
							id, ok := record.Attributes().Get("otel.entity.id")
							require.True(t, ok)
							require.NotEmpty(t, id.Map().AsRaw())
						}
					}
				}
			}
		}
		for _, name := range wantMetrics {
			if !foundMetrics[name] {
				return false
			}
		}
		for _, name := range wantEvents {
			if !foundEvents[name] {
				return false
			}
		}
		return foundTable
	}, 3*time.Minute, time.Second, "missing PostgreSQL telemetry: metrics=%v events=%v", foundMetrics, foundEvents)
	t.Logf("Collected PostgreSQL metrics %v and events %v", wantMetrics, wantEvents)
}

func checkDBMonitoringResource(t *testing.T, attrs pcommon.Map) {
	t.Helper()
	for key, expected := range map[string]string{
		"cx.db.instance.id":  "e2e/orders",
		"db.system.name":     "postgresql",
		"server.address":     "dbm-postgresql.db-monitoring-e2e.svc.cluster.local",
		"k8s.namespace.name": "db-monitoring-e2e",
	} {
		value, ok := attrs.Get(key)
		require.True(t, ok, "missing database attribute %s", key)
		require.Equal(t, expected, value.Str(), "database attribute %s", key)
	}
	_, hasHost := attrs.Get("host.name")
	require.False(t, hasHost, "collector host metadata must not describe the database")
}
