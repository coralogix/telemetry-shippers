// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

package e2e

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/pdata/pcommon"
	"go.opentelemetry.io/collector/pdata/pmetric"
)

var (
	statusCodeValues  = []string{"STATUS_CODE_UNSET", "STATUS_CODE_OK", "STATUS_CODE_ERROR"}
	resourceAttrsKeys = []string{
		"service.name",
		"k8s.cluster.name",
		"k8s.node.name",
		"k8s.namespace.name",
		"k8s.pod.name",
	}
	dbDimensionKeys = []string{
		"db.namespace",
		"db.operation.name",
		"db.collection.name",
		"db.system",
	}
	compactResourceAttrs = []string{
		"service.name",
		"k8s.cluster.name",
	}
)

// TestE2E_SpanMetrics_RegularMetrics ensures we keep emitting the same shape of span metrics
// (resource attributes, status.code OTTL shims, ms units) across collector/chart upgrades.
func TestE2E_SpanMetrics_RegularMetrics(t *testing.T) {
	scenario := getAgentScenario(t)
	require.NotEmpty(t, scenario.metrics, "Expected to receive metrics from span metrics connector")

	validateSpanMetricCase(t, scenario, spanMetricValidationCase{
		Name:             "regular span",
		MetricPrefix:     "",
		ResourceAttrKeys: resourceAttrsKeys,
	})
}

// TestE2E_SpanMetrics_DatabaseMetrics ensures db span metrics retain the expected shape between releases.
func TestE2E_SpanMetrics_DatabaseMetrics(t *testing.T) {
	scenario := getAgentScenario(t)
	require.NotEmpty(t, scenario.metrics, "Expected to receive metrics from span metrics connector")

	validateSpanMetricCase(t, scenario, spanMetricValidationCase{
		Name:              "database span",
		MetricPrefix:      "db.",
		ResourceAttrKeys:  resourceAttrsKeys,
		DatapointAttrKeys: dbDimensionKeys,
	})
}

// TestE2E_SpanMetrics_CompactMetrics ensures the compact span metrics pipeline preserves status.code shims
// and millisecond duration units across upgrades.
func TestE2E_SpanMetrics_CompactMetrics(t *testing.T) {
	scenario := getAgentScenario(t)
	require.NotEmpty(t, scenario.metrics, "Expected to receive metrics from span metrics connector")

	validateSpanMetricCase(t, scenario, spanMetricValidationCase{
		Name:             "compact span",
		MetricPrefix:     "compact.",
		ResourceAttrKeys: compactResourceAttrs,
	})
}

// TestE2E_SpanMetrics_DatabaseCompactMetrics validates the db_compact pipeline keeps exporting the
// reduced attribute set plus status.code restored by transform/spanmetrics.
func TestE2E_SpanMetrics_DatabaseCompactMetrics(t *testing.T) {
	scenario := getAgentScenario(t)
	require.NotEmpty(t, scenario.metrics, "Expected to receive metrics from span metrics connector")

	validateSpanMetricCase(t, scenario, spanMetricValidationCase{
		Name:             "database compact span",
		MetricPrefix:     "db_compact.",
		ResourceAttrKeys: compactResourceAttrs,
		DatapointAttrKeys: []string{
			"db.namespace",
			"db.system",
		},
	})
}

type spanMetricValidationCase struct {
	Name              string
	MetricPrefix      string
	ResourceAttrKeys  []string
	DatapointAttrKeys []string
}

func (c spanMetricValidationCase) metricName(suffix string) string {
	return c.MetricPrefix + suffix
}

func validateSpanMetricCase(t *testing.T, scenario agentScenarioResult, cfg spanMetricValidationCase) {
	t.Helper()

	expectedCalls := cfg.metricName("calls")
	expectedDuration := cfg.metricName("duration")

	metricsFound := map[string]bool{
		expectedCalls:    false,
		expectedDuration: false,
	}

	var resourceTracker map[string]bool
	var datapointTracker map[string]bool

	if len(cfg.ResourceAttrKeys) > 0 {
		resourceTracker = newAttributeTracker(cfg.ResourceAttrKeys)
	}
	if len(cfg.DatapointAttrKeys) > 0 {
		datapointTracker = newAttributeTracker(cfg.DatapointAttrKeys)
	}

	durationUnitValid := false
	statusCodeAttributeFound := false

	for _, metricsData := range scenario.metrics {
		for i := 0; i < metricsData.ResourceMetrics().Len(); i++ {
			rm := metricsData.ResourceMetrics().At(i)
			recordedForThisResource := false

			for j := 0; j < rm.ScopeMetrics().Len(); j++ {
				sm := rm.ScopeMetrics().At(j)

				if sm.Scope().Name() != "spanmetricsconnector" {
					continue
				}

				for k := 0; k < sm.Metrics().Len(); k++ {
					metric := sm.Metrics().At(k)

					switch metric.Name() {
					case expectedCalls:
						metricsFound[expectedCalls] = true
					case expectedDuration:
						metricsFound[expectedDuration] = true
						assert.Equalf(t, "ms", metric.Unit(), "%s duration metric should remain in milliseconds", cfg.Name)
						if metric.Unit() == "ms" {
							durationUnitValid = true
						}
					default:
						continue
					}

					if resourceTracker != nil && !recordedForThisResource {
						recordAttributes(rm.Resource().Attributes(), resourceTracker)
						recordedForThisResource = true
					}

					if datapointTracker != nil {
						updateDataPointAttributeTracker(metric, datapointTracker)
					}

					if verifyStatusCodeAttributes(t, metric) {
						statusCodeAttributeFound = true
					}
				}
			}
		}
	}

	require.Truef(t, metricsFound[expectedCalls], "Expected to find %s metric in %s metrics", expectedCalls, cfg.Name)
	require.Truef(t, metricsFound[expectedDuration], "Expected to find %s metric in %s metrics", expectedDuration, cfg.Name)
	require.Truef(t, durationUnitValid, "%s duration metric should continue to use 'ms'", cfg.Name)
	require.Truef(t, statusCodeAttributeFound, "Expected to find status.code attribute in %s metrics", cfg.Name)

	if resourceTracker != nil {
		require.Truef(t, trackerComplete(resourceTracker),
			"Missing expected resource attributes on %s metrics: %s",
			cfg.Name, strings.Join(missingAttributes(resourceTracker), ", "))
	}

	if datapointTracker != nil {
		require.Truef(t, trackerComplete(datapointTracker),
			"Missing expected datapoint attributes on %s metrics: %s",
			cfg.Name, strings.Join(missingAttributes(datapointTracker), ", "))
	}
}

func newAttributeTracker(keys []string) map[string]bool {
	tracker := make(map[string]bool, len(keys))
	for _, key := range keys {
		tracker[key] = false
	}
	return tracker
}

func recordAttributes(attrs pcommon.Map, tracker map[string]bool) {
	if tracker == nil {
		return
	}
	for key := range tracker {
		if _, ok := attrs.Get(key); ok {
			tracker[key] = true
		}
	}
}

func trackerComplete(tracker map[string]bool) bool {
	for _, seen := range tracker {
		if !seen {
			return false
		}
	}
	return true
}

func missingAttributes(tracker map[string]bool) []string {
	var missing []string
	for key, seen := range tracker {
		if !seen {
			missing = append(missing, key)
		}
	}
	return missing
}

func verifyStatusCodeAttributes(t *testing.T, metric pmetric.Metric) bool {
	found := false
	forEachDataPoint(metric, func(attrs pcommon.Map) {
		if statusCode, ok := attrs.Get("status.code"); ok {
			found = true
			assert.Contains(t, statusCodeValues, statusCode.AsString(),
				"status.code should use STATUS_CODE_* format (current behavior)")
		}
	})
	return found
}

func updateDataPointAttributeTracker(metric pmetric.Metric, tracker map[string]bool) {
	if tracker == nil {
		return
	}
	forEachDataPoint(metric, func(attrs pcommon.Map) {
		recordAttributes(attrs, tracker)
	})
}

func forEachDataPoint(metric pmetric.Metric, fn func(attrs pcommon.Map)) {
	switch metric.Type() {
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
	}
}
