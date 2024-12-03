package e2e

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/component/componenttest"
	"go.opentelemetry.io/collector/consumer/consumertest"
	"go.opentelemetry.io/collector/receiver/otlpreceiver"
	"go.opentelemetry.io/collector/receiver/receivertest"
)

const (
	equal = iota
	regex
	exist

	attributeMatchTypeEqual expectedValueMode = iota
	attributeMatchTypeRegex
	attributeMatchTypeExist

	serviceNameAttribute = "service.name"
)

type expectedValueMode int

type expectedTrace struct {
	name    string
	service string
	attrs   map[string]expectedValue
}

type expectedValue struct {
	mode  expectedValueMode
	value string
}

func newExpectedValue(mode expectedValueMode, value string) expectedValue {
	return expectedValue{
		mode:  mode,
		value: value,
	}
}

func startUpSinks(t *testing.T, mc *consumertest.MetricsSink, tc *consumertest.TracesSink) func() {
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

func waitForMetrics(t *testing.T, entriesNum int, mc *consumertest.MetricsSink) {
	timeout := 5 * time.Minute // 5 minutes
	require.Eventuallyf(t, func() bool {
		count := len(mc.AllMetrics())
		t.Logf("Waiting for metrics: got %d/%d", count, entriesNum)
		return count >= entriesNum
	}, timeout, 1*time.Second, "failed to receive %d entries in %s",
		entriesNum, timeout)
}

func waitForTraces(t *testing.T, entriesNum int, tc *consumertest.TracesSink) {
	timeout := 5 * time.Minute // 5 minutes
	require.Eventuallyf(t, func() bool {
		count := len(tc.AllTraces())
		t.Logf("Waiting for traces: got %d/%d", count, entriesNum)
		return count >= entriesNum
	}, timeout, 1*time.Second, "failed to receive %d entries in %s",
		entriesNum, timeout)
}
