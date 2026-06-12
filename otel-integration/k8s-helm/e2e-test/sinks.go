package e2e

import (
	"context"
	"strconv"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/component/componenttest"
	"go.opentelemetry.io/collector/consumer/consumertest"
	"go.opentelemetry.io/collector/receiver/otlpreceiver"
	"go.opentelemetry.io/collector/receiver/receivertest"
)

type expectedValueMode int

const (
	attributeMatchTypeEqual expectedValueMode = iota
	attributeMatchTypeRegex
	attributeMatchTypeExist
	attributeMatchTypeOptional
	attributeMatchTypeOptionalRegex
)

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

type ReceiverSinks struct {
	Metrics *MetricSinkConfig
	Traces  *TraceSinkConfig
	Logs    *LogSinkConfig
}

type MetricSinkConfig struct {
	Ports    *ReceiverPorts
	Consumer *consumertest.MetricsSink
}

type TraceSinkConfig struct {
	Ports    *ReceiverPorts
	Consumer *consumertest.TracesSink
}

type LogSinkConfig struct {
	Ports    *ReceiverPorts
	Consumer *consumertest.LogsSink
}

type ReceiverPorts struct {
	Grpc int
	Http int
}

// StartUpSinks creates and starts receivers with configurable ports and consumers
func StartUpSinks(t *testing.T, sinks ReceiverSinks) func() {

	shutDownFuncs := []func(){}

	if sinks.Metrics != nil {
		fMetric := otlpreceiver.NewFactory()
		cfg := fMetric.CreateDefaultConfig().(*otlpreceiver.Config)
		setupReceiverPorts(cfg, sinks.Metrics.Ports)
		metricsRcvr, err := fMetric.CreateMetrics(context.Background(), receivertest.NewNopSettings(), cfg, sinks.Metrics.Consumer)
		require.NoError(t, err, "failed creating metrics receiver")
		require.NoError(t, metricsRcvr.Start(context.Background(), componenttest.NewNopHost()))
		shutDownFuncs = append(shutDownFuncs, func() {
			assert.NoError(t, metricsRcvr.Shutdown(context.Background()))
		})
	}
	if sinks.Traces != nil {
		fTrace := otlpreceiver.NewFactory()
		cfg := fTrace.CreateDefaultConfig().(*otlpreceiver.Config)
		setupReceiverPorts(cfg, sinks.Traces.Ports)
		tracesRcvr, err := fTrace.CreateTraces(context.Background(), receivertest.NewNopSettings(), cfg, sinks.Traces.Consumer)
		require.NoError(t, err, "failed creating traces receiver")
		require.NoError(t, tracesRcvr.Start(context.Background(), componenttest.NewNopHost()))
		shutDownFuncs = append(shutDownFuncs, func() {
			assert.NoError(t, tracesRcvr.Shutdown(context.Background()))
		})
	}
	if sinks.Logs != nil {
		fLog := otlpreceiver.NewFactory()
		cfg := fLog.CreateDefaultConfig().(*otlpreceiver.Config)
		setupReceiverPorts(cfg, sinks.Logs.Ports)
		logsRcvr, err := fLog.CreateLogs(context.Background(), receivertest.NewNopSettings(), cfg, sinks.Logs.Consumer)
		require.NoError(t, err, "failed creating logs receiver")
		require.NoError(t, logsRcvr.Start(context.Background(), componenttest.NewNopHost()))
		shutDownFuncs = append(shutDownFuncs, func() {
			assert.NoError(t, logsRcvr.Shutdown(context.Background()))
		})
	}

	return func() {
		for _, f := range shutDownFuncs {
			f()
		}
	}
}

func setupReceiverPorts(cfg *otlpreceiver.Config, ports *ReceiverPorts) {
	if ports != nil {
		cfg.GRPC.NetAddr.Endpoint = "0.0.0.0:" + strconv.Itoa(ports.Grpc)
		cfg.HTTP.ServerConfig.Endpoint = "0.0.0.0:" + strconv.Itoa(ports.Http)
	} else {
		cfg.GRPC.NetAddr.Endpoint = "0.0.0.0:4317"
		cfg.HTTP.ServerConfig.Endpoint = "0.0.0.0:4318"
	}
}

// waitForMetrics waits for the specified number of metrics to be received
func waitForMetrics(t *testing.T, entriesNum int, mc *consumertest.MetricsSink) {
	timeout := 10 * time.Minute
	require.Eventuallyf(t, func() bool {
		count := len(mc.AllMetrics())
		t.Logf("Waiting for metrics: got %d/%d", count, entriesNum)
		return count >= entriesNum
	}, timeout, 1*time.Second, "failed to receive %d metrics in %s", entriesNum, timeout)
}

// waitForTraces waits for the specified number of traces to be received
func waitForTraces(t *testing.T, entriesNum int, tc *consumertest.TracesSink) {
	waitForTracesWithTimeout(t, entriesNum, tc, 10*time.Minute)
}

func waitForTracesWithTimeout(t *testing.T, entriesNum int, tc *consumertest.TracesSink, timeout time.Duration) {
	require.Eventuallyf(t, func() bool {
		count := len(tc.AllTraces())
		t.Logf("Waiting for traces: got %d/%d", count, entriesNum)
		return count >= entriesNum
	}, timeout, 1*time.Second, "failed to receive %d traces in %s", entriesNum, timeout)
}

// waitForLogs waits for the specified number of logs to be received
func waitForLogs(t *testing.T, entriesNum int, lc *consumertest.LogsSink) {
	timeout := 10 * time.Minute
	require.Eventuallyf(t, func() bool {
		count := len(lc.AllLogs())
		t.Logf("Waiting for logs: got %d/%d", count, entriesNum)
		return count >= entriesNum
	}, timeout, 1*time.Second, "failed to receive %d logs in %s", entriesNum, timeout)
}
