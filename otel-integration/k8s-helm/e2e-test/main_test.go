// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

package e2e

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"coralogix.com/otel-integration/e2e/testcommon/k8stest"

	"github.com/davecgh/go-spew/spew"
	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/consumer/consumertest"
	"go.opentelemetry.io/collector/pdata/pcommon"
	"go.opentelemetry.io/collector/pdata/pmetric"
	"go.opentelemetry.io/collector/pdata/ptrace"
)

func TestE2E_Agent(t *testing.T) {

	//Check if the HOST_ENDPOINT is set
	require.Equal(t, k8stest.HostEndpoint(t), os.Getenv("HOSTENDPOINT"), "HostEndpoints does not match env and detected")

	testDataDir := filepath.Join("testdata")

	k8sClient, err := k8stest.NewK8sClient()
	require.NoError(t, err)

	// Create the namespace specific for the test
	nsFile := filepath.Join(testDataDir, "namespace.yaml")
	buf, err := os.ReadFile(nsFile)
	require.NoErrorf(t, err, "failed to read namespace object file %s", nsFile)
	nsObj, err := k8stest.CreateObject(k8sClient, buf)
	require.NoErrorf(t, err, "failed to create k8s namespace from file %s", nsFile)

	testNs := nsObj.GetName()

	metricsConsumer := new(consumertest.MetricsSink)
	tracesConsumer := new(consumertest.TracesSink)
	shutdownSink := StartUpSinks(t, metricsConsumer, tracesConsumer)
	defer shutdownSink()

	testID := uuid.NewString()[:8]
	createTeleOpts := &k8stest.TelemetrygenCreateOpts{
		ManifestsDir: filepath.Join(testDataDir, "telemetrygen"),
		TestID:       testID,
		DataTypes:    []string{"traces"},
	}

	telemetryGenObjs, telemetryGenObjInfos := k8stest.CreateTelemetryGenObjects(t, k8sClient, createTeleOpts)
	for _, info := range telemetryGenObjInfos {
		k8stest.WaitForTelemetryGenToStart(t, k8sClient, info.Namespace, info.PodLabelSelectors, info.Workload, info.DataType)
	}

	t.Cleanup(func() {
		require.NoErrorf(t, k8stest.DeleteObject(k8sClient, nsObj), "failed to delete namespace %s", testNs)
		for _, obj := range telemetryGenObjs {
			require.NoErrorf(t, k8stest.DeleteObject(k8sClient, obj), "failed to delete object %s", obj.GetName())
		}
	})

	WaitForMetrics(t, 5, metricsConsumer)
	WaitForTraces(t, 10, tracesConsumer)

	checkResourceMetrics(t, metricsConsumer.AllMetrics())
	checkTracesAttributes(t, tracesConsumer.AllTraces(), testID)
}

func checkResourceMetrics(t *testing.T, actual []pmetric.Metrics) error {
	if len(actual) == 0 {
		t.Fatal("No resource metrics received")
	}

	for _, current := range actual {
		actualMetrics := pmetric.NewMetrics()
		current.CopyTo(actualMetrics)

		for i := 0; i < actualMetrics.ResourceMetrics().Len(); i++ {
			rmetrics := actualMetrics.ResourceMetrics().At(i)

			_, ok := expectedResourceSchemaURL[rmetrics.SchemaUrl()]
			require.True(t, ok, "schema_url %v does not match one of the expected values", rmetrics.SchemaUrl())
			if ok {
				expectedResourceSchemaURL[rmetrics.SchemaUrl()] = true
			}

			checkScopeMetrics(t, rmetrics)
		}
	}

	for name, expectedState := range expectedResourceSchemaURL {
		require.True(t, expectedState, "schema_url %v was not found in the actual metrics", name)
	}
	for name, expectedState := range expectedResourceScopeNames {
		require.True(t, expectedState, "scope %v was not found in the actual metrics", name)
	}

	var missingMetrics []string
	for name, expectedState := range expectedMetrics {
		if !expectedState {
			missingMetrics = append(missingMetrics, name)
		}
	}

	if len(missingMetrics) > 0 {
		t.Fatalf("metrics %v were not found in the actual metrics", missingMetrics)
	}

	return nil
}

func checkScopeMetrics(t *testing.T, rmetrics pmetric.ResourceMetrics) error {
	for k := 0; k < rmetrics.ScopeMetrics().Len(); k++ {
		scope := rmetrics.ScopeMetrics().At(k)

		// Ignore checking telemetrygen metrics (e.g. "gen")
		if len(scope.Scope().Name()) == 0 && len(scope.Scope().Version()) == 0 {
			continue
		}

		require.Equal(t, scope.Scope().Version(), expectedScopeVersion, "unexpected scope version %v")
		rmetrics.Resource().Attributes().Range(func(k string, v pcommon.Value) bool {
			fmt.Println("Resource Attributes: ", k, v.AsString())
			return true
		})

		_, ok := expectedResourceScopeNames[scope.Scope().Name()]
		if ok {
			expectedResourceScopeNames[scope.Scope().Name()] = true
		}
		require.True(t, ok, "scope %v does not match one of the expected values", scope.Scope().Name())

		// We only need the relevant part of the scopr name to get receiver name.
		scopeNameTrimmed := strings.Split(scope.Scope().Name(), "/")
		checkResourceAttributes(t, rmetrics.Resource().Attributes(), scopeNameTrimmed[4])

		metrics := scope.Metrics()

		for j := 0; j < metrics.Len(); j++ {
			metric := metrics.At(j)

			fmt.Println("Metric Name: ", metric.Name())
			_, ok := expectedMetrics[metric.Name()]
			if ok {
				expectedMetrics[metric.Name()] = true
			}
			if !ok {
				spew.Dump(metric)
			}
			require.True(t, ok, "metrics %v does not match one of the expected values", metric.Name())
		}
	}

	return nil
}

func checkResourceAttributes(t *testing.T, attributes pcommon.Map, scopeName string) error {
	var compareMap map[string]string

	switch scopeName {
	case "hostmetricsreceiver":
		compareMap = expectedResourceAttributesHostmetricsreceiver
	case "kubeletstatsreceiver":
		compareMap = expectedResourceAttributesKubeletstatreceiver
	case "prometheusreceiver":
		compareMap = expectedResourceAttributesPrometheusreceiver
	}

	attributes.Range(func(k string, v pcommon.Value) bool {
		val, ok := compareMap[k]
		require.True(t, ok, "unexpected attribute %v - scopeName: %s", k, scopeName)
		if val != "" {
			require.Equal(t, val, v.AsString(), "unexpected value for attribute %v", k)
		}
		return true
	})

	return nil
}

func checkTracesAttributes(t *testing.T, actual []ptrace.Traces, testID string) error {
	if len(actual) == 0 {
		t.Fatal("No traces received")
	}

	for _, current := range actual {
		actualTraces := ptrace.NewTraces()
		current.CopyTo(actualTraces)

		for i := 0; i < actualTraces.ResourceSpans().Len(); i++ {
			rspans := actualTraces.ResourceSpans().At(i)

			_, ok := expectedResourceSchemaURL[rspans.SchemaUrl()]
			require.True(t, ok, "traces resource %v does not match one of the expected values", rspans.SchemaUrl())
			if ok {
				expectedResourceSchemaURL[rspans.SchemaUrl()] = true
			}

			// checkResourceSpans(t, rspans)
		}
	}

	return nil
}
