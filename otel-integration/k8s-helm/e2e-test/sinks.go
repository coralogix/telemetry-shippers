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

	AttributeMatchTypeEqual ExpectedValueMode = iota
	AttributeMatchTypeRegex
	AttributeMatchTypeExist

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
