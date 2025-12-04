package e2e

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/open-telemetry/opentelemetry-collector-contrib/pkg/xk8stest"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/consumer/consumertest"
	"go.opentelemetry.io/collector/pdata/pcommon"
	"go.opentelemetry.io/collector/pdata/ptrace"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"
	"google.golang.org/grpc"
)

const (
	transactionEmitTimeout      = 45 * time.Second
	transactionTraceWaitTimeout = 3 * time.Minute
)

func TestE2E_TransactionsPreset(t *testing.T) {
	require.Equal(t, xk8stest.HostEndpoint(t), os.Getenv("HOSTENDPOINT"), "HostEndpoints does not match env and detected")

	kubeconfigPath := testKubeConfig
	if kubeConfigFromEnv := os.Getenv(kubeConfigEnvVar); kubeConfigFromEnv != "" {
		kubeconfigPath = kubeConfigFromEnv
	}

	k8sClient, err := xk8stest.NewK8sClient(kubeconfigPath)
	require.NoError(t, err)

	tracesConsumer := new(consumertest.TracesSink)
	shutdownSinks := StartUpSinks(t, ReceiverSinks{
		Traces: &TraceSinkConfig{
			Consumer: tracesConsumer,
			Ports: &ReceiverPorts{
				Grpc: 4321,
			},
		},
	})
	defer shutdownSinks()

	agentNamespace := agentCollectorNamespace()
	t.Logf("Waiting for agent collector in namespace=%s", agentNamespace)
	waitForAgentCollectorPod(t, k8sClient, agentNamespace)
	t.Log("Agent collector is running")

	localPort, stopPF := startPortForward(
		t,
		kubeconfigPath,
		agentNamespace,
		fmt.Sprintf("svc/%s", agentServiceName()),
		4317,
	)
	defer stopPF()
	t.Logf("Port forward established on 127.0.0.1:%d -> %s/%s:4317", localPort, agentNamespace, agentServiceName())

	ctx, cancel := context.WithTimeout(context.Background(), transactionEmitTimeout)
	defer cancel()

	serviceName := fmt.Sprintf("transactions-e2e-%s", uuid.NewString()[:8])
	t.Logf("Emitting trace for service=%s via endpoint=127.0.0.1:%d", serviceName, localPort)
	traceID, err := emitTransactionTrace(ctx, fmt.Sprintf("127.0.0.1:%d", localPort), serviceName)
	require.NoError(t, err)
	t.Logf("Trace emitted (traceID=%s)", traceID.String())

	waitForTracesWithTimeout(t, 1, tracesConsumer, transactionTraceWaitTimeout)
	t.Log("Traces received, verifying transaction attributes")

	verifyTransactionSpans(t, tracesConsumer, serviceName, traceID)
	t.Log("Transaction spans verified successfully")
}

func emitTransactionTrace(ctx context.Context, endpoint, serviceName string) (pcommon.TraceID, error) {
	exporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(endpoint),
		otlptracegrpc.WithInsecure(),
		otlptracegrpc.WithDialOption(grpc.WithBlock()),
	)
	if err != nil {
		return pcommon.TraceID{}, fmt.Errorf("create exporter: %w", err)
	}

	res, err := resource.Merge(resource.Default(), resource.NewWithAttributes(
		"",
		attribute.String(serviceNameAttribute, serviceName),
	))
	if err != nil {
		return pcommon.TraceID{}, fmt.Errorf("build resource: %w", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)
	tracer := tp.Tracer("transactions-e2e")

	rootCtx, rootSpan := tracer.Start(ctx, "transactions-root", trace.WithSpanKind(trace.SpanKindServer))
	traceID := pcommon.TraceID(rootSpan.SpanContext().TraceID())

	_, dbChild := tracer.Start(rootCtx, "transactions-db-child", trace.WithSpanKind(trace.SpanKindClient))
	dbChild.SetAttributes(attribute.String("db.system", "postgresql"))
	dbChild.End()

	_, internalChild := tracer.Start(rootCtx, "transactions-internal-child", trace.WithSpanKind(trace.SpanKindInternal))
	internalChild.End()

	_, producerChild := tracer.Start(rootCtx, "transactions-producer-child", trace.WithSpanKind(trace.SpanKindProducer))
	producerChild.End()

	consumerCtx, consumerSpan := tracer.Start(rootCtx, "transactions-consumer", trace.WithSpanKind(trace.SpanKindConsumer))
	_, downstream := tracer.Start(consumerCtx, "transactions-consumer-worker", trace.WithSpanKind(trace.SpanKindInternal))
	downstream.End()
	consumerSpan.End()

	_, preLabeledRoot := tracer.Start(rootCtx, "transactions-prelabeled", trace.WithSpanKind(trace.SpanKindInternal))
	preSetTransaction := "pre-set-transaction"
	preLabeledRoot.SetAttributes(
		attribute.String("cgx.transaction", preSetTransaction),
		attribute.Bool("cgx.transaction.root", true),
	)
	preLabeledRoot.End()
	rootSpan.End()

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := tp.Shutdown(shutdownCtx); err != nil {
		return pcommon.TraceID{}, fmt.Errorf("shutdown tracer provider: %w", err)
	}
	return traceID, nil
}

func verifyTransactionSpans(t *testing.T, sink *consumertest.TracesSink, serviceName string, expectedTraceID pcommon.TraceID) {
	t.Helper()

	deadline := time.Now().Add(transactionTraceWaitTimeout)
	var lastSamples []map[string]any

	for time.Now().Before(deadline) {
		spansByName, traceIDs, unmatched := collectTransactionSpans(sink.AllTraces(), serviceName)
		if len(traceIDs) == 0 {
			lastSamples = unmatched
			time.Sleep(2 * time.Second)
			continue
		}

		require.Lenf(t, traceIDs, 1, "expected a single trace ID for %s spans, got %v", serviceName, traceIDs)
		require.True(t, spansShareTraceID(spansByName, expectedTraceID), "not all spans belonged to the emitted trace")

		validateTransactionStructure(t, spansByName)
		return
	}

	require.Failf(t, "missing transaction spans", "expected spans for %s but none observed before timeout; most recent resources=%+v", serviceName, lastSamples)
}

func verifyTransactionSpansAbsence(t *testing.T, sink *consumertest.TracesSink, serviceName string, expectedTraceID pcommon.TraceID) {
	t.Helper()

	deadline := time.Now().Add(transactionTraceWaitTimeout)
	var lastSamples []map[string]any

	for time.Now().Before(deadline) {
		spansByName, traceIDs, unmatched := collectTransactionSpans(sink.AllTraces(), serviceName)
		if len(traceIDs) == 0 {
			lastSamples = unmatched
			time.Sleep(2 * time.Second)
			continue
		}

		require.Lenf(t, traceIDs, 1, "expected a single trace ID for %s spans, got %v", serviceName, traceIDs)
		require.True(t, spansShareTraceID(spansByName, expectedTraceID), "not all spans belonged to the emitted trace")

		for name, span := range spansByName {
			txAttr, hasTransaction := span.Attributes().Get("cgx.transaction")
			rootAttr, hasRoot := span.Attributes().Get("cgx.transaction.root")
			if name == "transactions-prelabeled" {
				require.Truef(t, hasTransaction, "pre-labeled span %q lost cgx.transaction attribute", name)
				require.Equal(t, "pre-set-transaction", txAttr.AsString(), "unexpected pre-labeled transaction name")
				require.Truef(t, hasRoot, "pre-labeled span %q lost cgx.transaction.root attribute", name)
				require.True(t, rootAttr.Bool(), "pre-labeled span root marker must remain true")
				continue
			}
			require.Falsef(t, hasTransaction, "span %q unexpectedly has cgx.transaction attribute", name)
			require.Falsef(t, hasRoot, "span %q unexpectedly has cgx.transaction.root attribute", name)
		}
		return
	}

	require.Failf(t, "missing spans", "expected spans for %s but none observed before timeout; most recent resources=%+v", serviceName, lastSamples)
}

func collectTransactionSpans(batches []ptrace.Traces, serviceName string) (map[string]ptrace.Span, map[string]struct{}, []map[string]any) {
	spansByName := map[string]ptrace.Span{}
	traceIDs := map[string]struct{}{}
	var unmatchedResources []map[string]any

	for _, batch := range batches {
		current := ptrace.NewTraces()
		batch.CopyTo(current)

		for i := 0; i < current.ResourceSpans().Len(); i++ {
			rs := current.ResourceSpans().At(i)
			resource := rs.Resource()
			nameAttr, ok := resource.Attributes().Get(serviceNameAttribute)
			if !ok || nameAttr.AsString() != serviceName {
				unmatchedResources = append(unmatchedResources, copyResourceAttributes(resource.Attributes()))
				continue
			}

			for j := 0; j < rs.ScopeSpans().Len(); j++ {
				scopeSpans := rs.ScopeSpans().At(j)
				for k := 0; k < scopeSpans.Spans().Len(); k++ {
					span := scopeSpans.Spans().At(k)
					spansByName[span.Name()] = span
					traceIDs[span.TraceID().String()] = struct{}{}
				}
			}
		}
	}

	return spansByName, traceIDs, unmatchedResources
}

func validateTransactionStructure(t *testing.T, spansByName map[string]ptrace.Span) {
	t.Helper()

	expected := []struct {
		name        string
		transaction string
		isRoot      bool
	}{
		{name: "transactions-root", transaction: "transactions-root", isRoot: true},
		{name: "transactions-db-child", transaction: "transactions-root", isRoot: false},
		{name: "transactions-internal-child", transaction: "transactions-root", isRoot: false},
		{name: "transactions-producer-child", transaction: "transactions-root", isRoot: false},
		{name: "transactions-consumer", transaction: "transactions-consumer", isRoot: true},
		{name: "transactions-consumer-worker", transaction: "transactions-consumer", isRoot: false},
		{name: "transactions-prelabeled", transaction: "pre-set-transaction", isRoot: true},
	}

	rootTransactions := map[string]struct{}{}
	for _, exp := range expected {
		span, ok := spansByName[exp.name]
		require.Truef(t, ok, "expected span %q not received (spans=%v)", exp.name, mapKeys(spansByName))
		assertTransactionAttributes(t, span, exp.transaction, exp.isRoot)
		if exp.isRoot {
			rootTransactions[exp.transaction] = struct{}{}
		}
	}

	for _, exp := range expected {
		if exp.isRoot {
			continue
		}
		_, ok := rootTransactions[exp.transaction]
		require.Truef(t, ok, "child span %q references missing transaction root %q", exp.name, exp.transaction)
	}
}

func assertTransactionAttributes(t *testing.T, span ptrace.Span, expectedTransaction string, expectRoot bool) {
	t.Helper()

	txAttr, ok := span.Attributes().Get("cgx.transaction")
	require.Truef(t, ok, "span %q missing cgx.transaction attribute", span.Name())
	require.Equalf(t, expectedTransaction, txAttr.AsString(), "unexpected transaction name for span %q", span.Name())

	rootAttr, hasRoot := span.Attributes().Get("cgx.transaction.root")
	if expectRoot {
		require.Truef(t, hasRoot, "span %q should include cgx.transaction.root", span.Name())
		require.Equal(t, pcommon.ValueTypeBool, rootAttr.Type())
		require.Truef(t, rootAttr.Bool(), "span %q cgx.transaction.root must be true", span.Name())
	} else {
		require.Falsef(t, hasRoot, "span %q should not include cgx.transaction.root", span.Name())
	}
}

func mapKeys(m map[string]ptrace.Span) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}

func spansShareTraceID(spans map[string]ptrace.Span, expected pcommon.TraceID) bool {
	for _, span := range spans {
		if span.TraceID() != expected {
			return false
		}
	}
	return true
}

func copyResourceAttributes(attrs pcommon.Map) map[string]any {
	out := make(map[string]any, attrs.Len())
	attrs.Range(func(k string, v pcommon.Value) bool {
		out[k] = v.AsRaw()
		return true
	})
	return out
}
