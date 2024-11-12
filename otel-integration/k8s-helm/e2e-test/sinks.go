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

type ReceiverSinks struct {
	MetricsConsumer *consumertest.MetricsSink
	TracesConsumer  *consumertest.TracesSink
}

func StartUpSinks(t *testing.T, sinks ReceiverSinks) func() {
	shutDownFuncs := []func(){}

	if sinks.MetricsConsumer != nil {
		fMetric := otlpreceiver.NewFactory()
		cfg := fMetric.CreateDefaultConfig().(*otlpreceiver.Config)
		metricsRcvr, err := fMetric.CreateMetricsReceiver(context.Background(), receivertest.NewNopCreateSettings(), cfg, sinks.MetricsConsumer)
		require.NoError(t, metricsRcvr.Start(context.Background(), componenttest.NewNopHost()))
		require.NoError(t, err, "failed creating metrics receiver")
		shutDownFuncs = append(shutDownFuncs, func() {
			assert.NoError(t, metricsRcvr.Shutdown(context.Background()))
		})
	}

	if sinks.TracesConsumer != nil {
		fTrace := otlpreceiver.NewFactory()
		cfg := fTrace.CreateDefaultConfig().(*otlpreceiver.Config)
		traceRcvr, err := fTrace.CreateTracesReceiver(context.Background(), receivertest.NewNopCreateSettings(), cfg, sinks.TracesConsumer)
		require.NoError(t, traceRcvr.Start(context.Background(), componenttest.NewNopHost()))
		require.NoError(t, err, "failed creating traces receiver")
		shutDownFuncs = append(shutDownFuncs, func() {
			assert.NoError(t, traceRcvr.Shutdown(context.Background()))
		})
	}

	return func() {
		for _, f := range shutDownFuncs {
			f()
		}
	}
}

func WaitForMetrics(t *testing.T, entriesNum int, mc *consumertest.MetricsSink) {
	timeoutMinutes := 5
	require.Eventually(t, func() bool {
		return len(mc.AllMetrics()) >= entriesNum
	}, time.Duration(timeoutMinutes)*time.Minute, time.Second,
		"failed to receive %d entries,  received %d metrics in %d minutes",
		entriesNum, len(mc.AllMetrics()), timeoutMinutes)
}

func WaitForTraces(t *testing.T, entriesNum int, tc *consumertest.TracesSink) {
	timeoutMinutes := 5
	require.Eventually(t, func() bool {
		return len(tc.AllTraces()) >= entriesNum
	}, time.Duration(timeoutMinutes)*time.Minute, time.Second,
		"failed to receive %d entries,  received %d traces in %d minutes",
		entriesNum, len(tc.AllTraces()), timeoutMinutes)
}
