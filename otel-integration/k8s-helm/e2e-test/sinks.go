package e2e

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"regexp"
	"slices"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/component/componenttest"
	"go.opentelemetry.io/collector/consumer/consumertest"
	"go.opentelemetry.io/collector/pdata/pcommon"
	"go.opentelemetry.io/collector/pdata/pmetric"
	"go.opentelemetry.io/collector/receiver/otlpreceiver"
	"go.opentelemetry.io/collector/receiver/receivertest"
)

const (
	equal = iota
	regex
	exist

	AttributeMatchTypeEqual ExpectedValueMode = iota
	AttributeMatchTypeRegex
	AttributeMatchTypeExist
	UidRe = "[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}"

	ServiceNameAttribute = "service.name"
)

type ExpectedValueMode int

type ExpectedTrace struct {
	name    string
	service string
	attrs   map[string]ExpectedValue
}

type ExpectedValue struct {
	Mode  ExpectedValueMode
	Value string
}

func NewExpectedValue(mode ExpectedValueMode, value string) ExpectedValue {
	return ExpectedValue{
		Mode:  mode,
		Value: value,
	}
}

func StartUpSinks(t *testing.T, mc *consumertest.MetricsSink, tc *consumertest.TracesSink) func() {
	f := otlpreceiver.NewFactory()
	cfg := f.CreateDefaultConfig().(*otlpreceiver.Config)
	cfg.HTTP = nil
	cfg.GRPC.NetAddr.Endpoint = "0.0.0.0:4317"

	_, err := f.CreateMetrics(context.Background(), receivertest.NewNopSettings(), cfg, mc)
	require.NoError(t, err, "failed creating metrics receiver")
	rcvr, err := f.CreateTraces(context.Background(), receivertest.NewNopSettings(), cfg, tc)
	require.NoError(t, err, "failed creating traces receiver")
	require.NoError(t, rcvr.Start(context.Background(), componenttest.NewNopHost()))

	return func() {
		assert.NoError(t, rcvr.Shutdown(context.Background()))
	}
}

func WaitForMetrics(t *testing.T, entriesNum int, mc *consumertest.MetricsSink) {
	timeoutSeconds := 180 // 3 minutes
	require.Eventuallyf(t, func() bool {
		count := len(mc.AllMetrics())
		t.Logf("Waiting for metrics: got %d/%d", count, entriesNum)
		return count >= entriesNum
	}, time.Duration(timeoutSeconds)*time.Second, 1*time.Second,
		"failed to receive %d entries in %d seconds",
		entriesNum, timeoutSeconds)
}

func WaitForTraces(t *testing.T, entriesNum int, tc *consumertest.TracesSink) {
	timeoutSeconds := 180 // 3 minutes
	require.Eventuallyf(t, func() bool {
		count := len(tc.AllTraces())
		t.Logf("Waiting for traces: got %d/%d", count, entriesNum)
		return count >= entriesNum // Changed > to >=
	}, time.Duration(timeoutSeconds)*time.Second, 1*time.Second,
		"failed to receive %d entries in %d seconds",
		entriesNum, timeoutSeconds)
}

func ScanTracesForAttributes(t *testing.T, ts *consumertest.TracesSink, expectedService string, kvs map[string]ExpectedValue, scopeSpanAttrs []map[string]ExpectedValue) {
	for i := 0; i < len(ts.AllTraces()); i++ {
		traces := ts.AllTraces()[i]
		for i := 0; i < traces.ResourceSpans().Len(); i++ {
			resource := traces.ResourceSpans().At(i).Resource()
			service, exist := resource.Attributes().Get(ServiceNameAttribute)
			assert.True(t, exist, "Resource does not have the 'service.name' attribute")
			if service.AsString() != expectedService {
				continue
			}
			assert.NoError(t, assertExpectedAttributes(resource.Attributes(), kvs))

			if len(scopeSpanAttrs) == 0 {
				return
			}

			assert.NotZero(t, traces.ResourceSpans().At(i).ScopeSpans().Len())
			assert.NotZero(t, traces.ResourceSpans().At(i).ScopeSpans().At(0).Spans().Len())

			scopeSpan := traces.ResourceSpans().At(i).ScopeSpans().At(0)

			// look for matching spans containing the desired attributes
			for _, spanAttrs := range scopeSpanAttrs {
				var err error
				for j := 0; j < scopeSpan.Spans().Len(); j++ {
					err = assertExpectedAttributes(scopeSpan.Spans().At(j).Attributes(), spanAttrs)
					if err == nil {
						break
					}
				}
				assert.NoError(t, err)
			}

			return
		}
	}
	t.Fatalf("no spans found for service %s", expectedService)
}

func assertExpectedAttributes(attrs pcommon.Map, kvs map[string]ExpectedValue) error {
	foundAttrs := make(map[string]bool)
	for k := range kvs {
		foundAttrs[k] = false
	}

	attrs.Range(func(k string, v pcommon.Value) bool {
		if val, ok := kvs[k]; ok {
			switch val.Mode {
			case AttributeMatchTypeEqual:
				if val.Value == v.AsString() {
					foundAttrs[k] = true
				}
			case AttributeMatchTypeRegex:
				matched, _ := regexp.MatchString(val.Value, v.AsString())
				if matched {
					foundAttrs[k] = true
				}
			case AttributeMatchTypeExist:
				foundAttrs[k] = true
			}
		}
		return true
	},
	)

	var err error
	for k, v := range foundAttrs {
		if !v {
			err = errors.Join(err, fmt.Errorf("attribute '%v' not found", k))
		}
	}
	if err != nil {
		// if something is missing, add a summary with an overview of the expected and actual attributes for easier troubleshooting
		expectedJson, _ := json.MarshalIndent(kvs, "", "  ")
		actualJson, _ := json.MarshalIndent(attrs.AsRaw(), "", "  ")
		err = errors.Join(err, fmt.Errorf("one or more attributes were not found.\nExpected attributes:\n %s \nActual attributes: \n%s", expectedJson, actualJson))
	}
	return err
}

// ScanForServiceMetrics asserts that the metrics sink provided in the arguments
// contains the given metrics for a service
func ScanForServiceMetrics(t *testing.T, ms *consumertest.MetricsSink, expectedService string, expectedMetrics []string) {
	for _, r := range ms.AllMetrics() {
		for i := 0; i < r.ResourceMetrics().Len(); i++ {
			resource := r.ResourceMetrics().At(i).Resource()
			service, exist := resource.Attributes().Get(ServiceNameAttribute)
			assert.Equal(t, true, exist, "resource does not have the 'service.name' attribute")
			if service.AsString() != expectedService {
				continue
			}

			sm := r.ResourceMetrics().At(i).ScopeMetrics().At(0).Metrics()
			assert.NoError(t, assertExpectedMetrics(expectedMetrics, sm))
			return
		}
	}
	t.Fatalf("no metric found for service %s", expectedService)
}

func assertExpectedMetrics(expectedMetrics []string, sm pmetric.MetricSlice) error {
	var actualMetrics []string
	for i := 0; i < sm.Len(); i++ {
		actualMetrics = append(actualMetrics, sm.At(i).Name())
	}

	for _, m := range expectedMetrics {
		if !slices.Contains(actualMetrics, m) {
			return fmt.Errorf("metric: %s not found", m)
		}
	}
	return nil
}
