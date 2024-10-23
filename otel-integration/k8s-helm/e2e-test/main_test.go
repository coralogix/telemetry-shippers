// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

package e2e

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/davecgh/go-spew/spew"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/component/componenttest"
	"go.opentelemetry.io/collector/consumer/consumertest"
	"go.opentelemetry.io/collector/pdata/pcommon"
	"go.opentelemetry.io/collector/pdata/pmetric"
	"go.opentelemetry.io/collector/receiver/otlpreceiver"
	"go.opentelemetry.io/collector/receiver/receivertest"
)

func TestE2E_Agent(t *testing.T) {
	metricsConsumer := new(consumertest.MetricsSink)
	shutdownSink := startUpSink(t, metricsConsumer)
	defer shutdownSink()

	waitTime := 2 * time.Minute
	waitForData(waitTime)

	checkResourceMetrics(t, metricsConsumer.AllMetrics())
}

func startUpSink(t *testing.T, mc *consumertest.MetricsSink) func() {
	f := otlpreceiver.NewFactory()
	cfg := f.CreateDefaultConfig().(*otlpreceiver.Config)

	rcvr, err := f.CreateMetricsReceiver(context.Background(), receivertest.NewNopCreateSettings(), cfg, mc)
	require.NoError(t, rcvr.Start(context.Background(), componenttest.NewNopHost()))
	require.NoError(t, err, "failed creating metrics receiver")
	return func() {
		assert.NoError(t, rcvr.Shutdown(context.Background()))
	}
}

func waitForData(wait time.Duration) {
	deadline := time.Now().Add(wait)
	for {
		if time.Now().After(deadline) {
			break
		}
	}
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

			_, ok := expectedSchemaURL[rmetrics.SchemaUrl()]
			require.True(t, ok, "schema_url %v does not match one of the expected values", rmetrics.SchemaUrl())
			if ok {
				expectedSchemaURL[rmetrics.SchemaUrl()] = true
			}

			checkScopeMetrics(t, rmetrics)
		}
	}

	for name, expectedState := range expectedSchemaURL {
		require.True(t, expectedState, "schema_url %v was not found in the actual metrics", name)
	}
	for name, expectedState := range expectedScopeNames {
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

		require.Equal(t, scope.Scope().Version(), expectedScopeVersion, "unexpected scope version %v")
		_, ok := expectedScopeNames[scope.Scope().Name()]
		if ok {
			expectedScopeNames[scope.Scope().Name()] = true
		}
		require.True(t, ok, "scope %v does not match one of the expected values", scope.Scope().Name())

		// We only need the relevant part of the scopr name to get receiver name.
		scopeNameTrimmed := strings.Split(scope.Scope().Name(), "/")
		checkResourceAttributes(t, rmetrics.Resource().Attributes(), scopeNameTrimmed[4])

		metrics := scope.Metrics()
		for j := 0; j < metrics.Len(); j++ {
			metric := metrics.At(j)

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
