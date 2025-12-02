package e2e

import (
	"bytes"
	"context"
	"fmt"
	"net"
	"os"
	"os/exec"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/open-telemetry/opentelemetry-collector-contrib/pkg/xk8stest"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/consumer/consumertest"
	"go.opentelemetry.io/collector/pdata/pmetric"
	"go.opentelemetry.io/collector/pdata/ptrace"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"
	"google.golang.org/grpc"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type spanSanitizationExpectation struct {
	serviceName   string
	sanitizedName string
}

func TestE2E_SpanSanitization(t *testing.T) {
	require.Equal(t, xk8stest.HostEndpoint(t), os.Getenv("HOSTENDPOINT"), "HostEndpoints does not match env and detected")

	kubeconfigPath := testKubeConfig
	if kubeConfigFromEnv := os.Getenv(kubeConfigEnvVar); kubeConfigFromEnv != "" {
		kubeconfigPath = kubeConfigFromEnv
	}

	k8sClient, err := xk8stest.NewK8sClient(kubeconfigPath)
	require.NoError(t, err)
	t.Logf("Connected to cluster using kubeconfig %q", kubeconfigPath)

	metricsConsumer := new(consumertest.MetricsSink)
	tracesConsumer := new(consumertest.TracesSink)
	shutdownSinks := StartUpSinks(t, ReceiverSinks{
		Metrics: &MetricSinkConfig{
			Consumer: metricsConsumer,
			Ports: &ReceiverPorts{
				Grpc: 4317,
			},
		},
		Traces: &TraceSinkConfig{
			Consumer: tracesConsumer,
			Ports: &ReceiverPorts{
				Grpc: 4321,
			},
		},
	})
	defer shutdownSinks()

	testID := uuid.NewString()[:8]
	spanInputs, expectations := buildSanitizationSpanInputs(testID)

	agentNamespace := agentCollectorNamespace()
	t.Logf("Using agent collector namespace %q", agentNamespace)
	agentPod := waitForAgentCollectorPod(t, k8sClient, agentNamespace)
	t.Logf("Found running agent collector pod %q", agentPod)
	agentService := agentServiceName()
	t.Logf("Using agent collector service %q", agentService)
	otlpPort, stopPF := startPortForward(t, kubeconfigPath, agentNamespace, fmt.Sprintf("svc/%s", agentService), 4317)
	defer stopPF()
	t.Logf("Established port-forward to service %s:%d via local port %d", agentService, 4317, otlpPort)

	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Minute)
	defer cancel()
	require.NoError(t, emitSyntheticSpans(t, ctx, fmt.Sprintf("127.0.0.1:%d", otlpPort), spanInputs))

	waitForTraces(t, 1, tracesConsumer)

	assertSanitizedTraces(t, tracesConsumer.AllTraces(), expectations)
	assertSanitizedSpanMetrics(t, metricsConsumer, expectations)
}

func assertSanitizedTraces(t *testing.T, batches []ptrace.Traces, expectations []spanSanitizationExpectation) {
	t.Helper()

	serviceSpanNames := map[string]map[string]struct{}{}

	for _, batch := range batches {
		current := ptrace.NewTraces()
		batch.CopyTo(current)

		for i := 0; i < current.ResourceSpans().Len(); i++ {
			rs := current.ResourceSpans().At(i)
			resource := rs.Resource()
			serviceName, ok := resource.Attributes().Get(serviceNameAttribute)
			if !ok {
				continue
			}
			if _, exists := serviceSpanNames[serviceName.AsString()]; !exists {
				serviceSpanNames[serviceName.AsString()] = make(map[string]struct{})
			}

			for j := 0; j < rs.ScopeSpans().Len(); j++ {
				scopeSpans := rs.ScopeSpans().At(j)
				for k := 0; k < scopeSpans.Spans().Len(); k++ {
					span := scopeSpans.Spans().At(k)
					name := span.Name()
					require.NotEqual(t, "...", name, "span name must not be ellipsis")
					require.NotEqual(t, "*", name, "span name must not be wildcard star")

					serviceSpanNames[serviceName.AsString()][name] = struct{}{}
				}
			}
		}
	}

	for _, exp := range expectations {
		names, ok := serviceSpanNames[exp.serviceName]
		require.Truef(t, ok, "no spans received for service %s", exp.serviceName)

		_, hasExpected := names[exp.sanitizedName]
		assert.Truef(t, hasExpected, "sanitized span name %q not found for service %s (found: %v)", exp.sanitizedName, exp.serviceName, mapKeys(names))
	}
}

func mapKeys(m map[string]struct{}) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}

func assertSanitizedSpanMetrics(t *testing.T, metricsConsumer *consumertest.MetricsSink, expectations []spanSanitizationExpectation) {
	t.Helper()

	require.Eventually(t, func() bool {
		return sanitizedSpanMetricsPresent(t, metricsConsumer.AllMetrics(), expectations)
	}, 2*time.Minute, 2*time.Second, "sanitized span metrics not observed in time")
}

func sanitizedSpanMetricsPresent(t *testing.T, batches []pmetric.Metrics, expectations []spanSanitizationExpectation) bool {
	t.Helper()

	expectedMap := make(map[string]bool, len(expectations))
	for _, exp := range expectations {
		key := fmt.Sprintf("%s|%s", exp.serviceName, exp.sanitizedName)
		expectedMap[key] = false
	}

	for _, batch := range batches {
		current := pmetric.NewMetrics()
		batch.CopyTo(current)

		for i := 0; i < current.ResourceMetrics().Len(); i++ {
			rm := current.ResourceMetrics().At(i)
			for j := 0; j < rm.ScopeMetrics().Len(); j++ {
				sm := rm.ScopeMetrics().At(j)
				for k := 0; k < sm.Metrics().Len(); k++ {
					metric := sm.Metrics().At(k)
					if metric.Name() != "calls" || metric.Type() != pmetric.MetricTypeSum {
						continue
					}
					sum := metric.Sum()
					for dpIdx := 0; dpIdx < sum.DataPoints().Len(); dpIdx++ {
						dp := sum.DataPoints().At(dpIdx)
						spanName, ok := dp.Attributes().Get("span.name")
						if !ok {
							continue
						}
						require.NotEqual(t, "...", spanName.AsString(), "spanmetrics span.name must not be ellipsis")
						require.NotEqual(t, "*", spanName.AsString(), "spanmetrics span.name must not be wildcard star")

						serviceName, ok := dp.Attributes().Get(serviceNameAttribute)
						if !ok {
							continue
						}

						key := fmt.Sprintf("%s|%s", serviceName.AsString(), spanName.AsString())
						if _, expExists := expectedMap[key]; expExists {
							expectedMap[key] = true
						}
					}
				}
			}
		}
	}

	for key, found := range expectedMap {
		if !found {
			t.Logf("spanmetrics datapoint for %s not yet observed", key)
			return false
		}
	}

	return true
}

type syntheticSpan struct {
	serviceName string
	name        string
	kind        trace.SpanKind
	attributes  []attribute.KeyValue
}

func buildSanitizationSpanInputs(testID string) ([]syntheticSpan, []spanSanitizationExpectation) {
	service := func(label string) string {
		return fmt.Sprintf("span-sanitization-%s-%s", label, testID)
	}

	longURLSpan := "/api/" + strings.Repeat("segment/", 100) + "end"

	cases := []struct {
		serviceName string
		name        string
		kind        trace.SpanKind
		attrs       []attribute.KeyValue
		sanitized   string
	}{
		{
			serviceName: service("okey"),
			name:        "okey-dokey-0",
			kind:        trace.SpanKindClient,
			attrs: []attribute.KeyValue{
				attribute.String("http.method", "GET"),
				attribute.String("http.request.method", "GET"),
			},
			sanitized: "okey-dokey-0",
		},
		{
			serviceName: service("http"),
			name:        "GET /orders/123456/detail/7890",
			kind:        trace.SpanKindServer,
			attrs: []attribute.KeyValue{
				attribute.String("http.method", "GET"),
				attribute.String("url.full", "https://shop.example.com/orders/123456/detail/7890?card=4111111111111111"),
			},
			sanitized: "GET /orders/*/detail/*",
		},
		{
			serviceName: service("http-path-only"),
			name:        "/users/123/profile",
			kind:        trace.SpanKindClient,
			sanitized:   "/users/*/profile",
		},
		{
			serviceName: service("http-unicode"),
			name:        "/users/测试/profile",
			kind:        trace.SpanKindClient,
			sanitized:   "/users/*/profile",
		},
		{
			serviceName: service("http-special"),
			name:        "/api/v1/items/@special/data",
			kind:        trace.SpanKindClient,
			sanitized:   "/api/v1/items/*/data",
		},
		{
			serviceName: service("http-fragment"),
			name:        "GET /page/123#section",
			kind:        trace.SpanKindClient,
			sanitized:   "GET /page/*",
		},
		{
			serviceName: service("http-long"),
			name:        longURLSpan,
			kind:        trace.SpanKindClient,
			sanitized:   "/api/segment/segment/segment/segment/segment/segment/segment/segment",
		},
		{
			serviceName: service("http-internal"),
			name:        "/internal/process/123",
			kind:        trace.SpanKindInternal,
			sanitized:   "/internal/process/123",
		},
		{
			serviceName: service("sql"),
			name:        "SELECT balance FROM accounts WHERE account_id = 123456",
			kind:        trace.SpanKindClient,
			attrs: []attribute.KeyValue{
				attribute.String("db.statement", "SELECT balance FROM accounts WHERE account_id = 123456"),
				attribute.String("db.system", "mysql"),
				attribute.String("db.system.name", "mysql"),
			},
			sanitized: "SELECT balance FROM accounts WHERE account_id = ?",
		},
		{
			serviceName: service("sql-postgresql"),
			name:        "SELECT * FROM users WHERE id = 42",
			kind:        trace.SpanKindClient,
			attrs: []attribute.KeyValue{
				attribute.String("db.system", "postgresql"),
			},
			sanitized: "SELECT * FROM users WHERE id = ?",
		},
		{
			serviceName: service("sql-mariadb"),
			name:        "UPDATE accounts SET balance = 100 WHERE id = 7",
			kind:        trace.SpanKindClient,
			attrs: []attribute.KeyValue{
				attribute.String("db.system", "mariadb"),
			},
			sanitized: "UPDATE accounts SET balance = ? WHERE id = ?",
		},
		{
			serviceName: service("sql-sqlite"),
			name:        "DELETE FROM sessions WHERE expired < 1234567890",
			kind:        trace.SpanKindClient,
			attrs: []attribute.KeyValue{
				attribute.String("db.system", "sqlite"),
			},
			sanitized: "DELETE FROM sessions WHERE expired < ?",
		},
		{
			serviceName: service("redis"),
			name:        "SET cart:user:12345 top-secret",
			kind:        trace.SpanKindClient,
			attrs: []attribute.KeyValue{
				attribute.String("db.system", "redis"),
				attribute.String("db.system.name", "redis"),
			},
			sanitized: "SET cart:user:12345 ?",
		},
		{
			serviceName: service("memcached"),
			name:        "set key 0 60 5\r\nsecret\r\n",
			kind:        trace.SpanKindClient,
			attrs: []attribute.KeyValue{
				attribute.String("db.system", "memcached"),
				attribute.String("db.system.name", "memcached"),
			},
			sanitized: "set key 0 60 5",
		},
		{
			serviceName: service("mongo"),
			name:        `{"find":"users","filter":{"name":"alice"}}`,
			kind:        trace.SpanKindClient,
			attrs: []attribute.KeyValue{
				attribute.String("db.system", "mongodb"),
				attribute.String("db.system.name", "mongodb"),
			},
			sanitized: `{"find":"?","filter":{"name":"?"}}`,
		},
		{
			serviceName: service("opensearch"),
			name:        `{"query":{"match":{"title":"classified"}}}`,
			kind:        trace.SpanKindClient,
			attrs: []attribute.KeyValue{
				attribute.String("db.system", "opensearch"),
				attribute.String("db.system.name", "opensearch"),
			},
			sanitized: `{"query":{"match":{"title":"?"}}}`,
		},
		{
			serviceName: service("elasticsearch"),
			name:        `{"query":{"match":{"title":"hidden"}}}`,
			kind:        trace.SpanKindClient,
			attrs: []attribute.KeyValue{
				attribute.String("db.system", "elasticsearch"),
				attribute.String("db.system.name", "elasticsearch"),
			},
			sanitized: `{"query":{"match":{"title":"?"}}}`,
		},
		{
			serviceName: service("url-query"),
			name:        "GET /reports/7?sql=SELECT+1",
			kind:        trace.SpanKindServer,
			attrs: []attribute.KeyValue{
				attribute.String("http.method", "GET"),
			},
			sanitized: "GET /reports/*",
		},
		{
			serviceName: service("sql-newlines"),
			name:        "SELECT *\nFROM users\nWHERE id = 42",
			kind:        trace.SpanKindClient,
			attrs: []attribute.KeyValue{
				attribute.String("db.system", "mysql"),
			},
			sanitized: "SELECT *\nFROM users\nWHERE id = ?",
		},
		{
			serviceName: service("db-system-name-only"),
			name:        "SELECT count(*) FROM payments WHERE user_id = 42",
			kind:        trace.SpanKindClient,
			attrs: []attribute.KeyValue{
				attribute.String("db.system.name", "postgresql"),
			},
			sanitized: "SELECT count(*) FROM payments WHERE user_id = ?",
		},
		{
			serviceName: service("no-db-system"),
			name:        "SELECT * FROM cache WHERE key = 'user:123'",
			kind:        trace.SpanKindClient,
			sanitized:   "SELECT * FROM cache WHERE key = 'user:123'",
		},
		{
			serviceName: service("invalid-json"),
			name:        `{"find":"users"`,
			kind:        trace.SpanKindClient,
			attrs: []attribute.KeyValue{
				attribute.String("db.system", "mongodb"),
				attribute.String("db.system.name", "mongodb"),
			},
			sanitized: `{"find":"users"`,
		},
		{
			serviceName: service("http-service-identifiers"),
			name:        "payments-dev-sql-adapter-queue /api/process/123",
			kind:        trace.SpanKindServer,
			attrs: []attribute.KeyValue{
				attribute.String("http.method", "POST"),
			},
			sanitized: "payments-dev-sql-adapter-queue /api/process/*",
		},
		{
			serviceName: service("http-no-slash"),
			name:        "payments-dev-sql-adapter-queue process",
			kind:        trace.SpanKindServer,
			attrs: []attribute.KeyValue{
				attribute.String("http.method", "POST"),
			},
			sanitized: "payments-dev-sql-adapter-queue process",
		},
		{
			serviceName: service("json-like"),
			name:        `{"message":"hello"}`,
			kind:        trace.SpanKindClient,
			sanitized:   `{"message":"hello"}`,
		},
		{
			serviceName: service("slash-only"),
			name:        "/",
			kind:        trace.SpanKindClient,
			sanitized:   "/",
		},
	}

	spans := make([]syntheticSpan, 0, len(cases))
	expectations := make([]spanSanitizationExpectation, 0, len(cases))
	for _, c := range cases {
		spans = append(spans, syntheticSpan{
			serviceName: c.serviceName,
			name:        c.name,
			kind:        c.kind,
			attributes:  c.attrs,
		})
		expectations = append(expectations, spanSanitizationExpectation{
			serviceName:   c.serviceName,
			sanitizedName: c.sanitized,
		})
	}

	return spans, expectations
}

func emitSyntheticSpans(t *testing.T, ctx context.Context, endpoint string, spans []syntheticSpan) error {
	for _, span := range spans {
		start := time.Now()
		if err := emitSingleSpan(ctx, endpoint, span); err != nil {
			return err
		}
		t.Logf("sent synthetic span %q for service %q in %s", span.name, span.serviceName, time.Since(start))
	}
	return nil
}

func emitSingleSpan(parent context.Context, endpoint string, testSpan syntheticSpan) error {
	ctx, cancel := context.WithTimeout(parent, 30*time.Second)
	defer cancel()

	exporter, err := otlptracegrpc.New(ctx,
		otlptracegrpc.WithEndpoint(endpoint),
		otlptracegrpc.WithInsecure(),
		otlptracegrpc.WithDialOption(grpc.WithBlock()),
	)
	if err != nil {
		return fmt.Errorf("create exporter: %w", err)
	}

	res, err := resource.Merge(resource.Default(), resource.NewWithAttributes(
		"",
		attribute.String(serviceNameAttribute, testSpan.serviceName),
	))
	if err != nil {
		return fmt.Errorf("build resource: %w", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)
	tracer := tp.Tracer("span-sanitization-e2e")

	_, span := tracer.Start(ctx, testSpan.name, trace.WithSpanKind(testSpan.kind))
	span.SetAttributes(testSpan.attributes...)
	span.End()

	shutdownCtx, cancelShutdown := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancelShutdown()

	if err := tp.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("shutdown tracer provider: %w", err)
	}
	return nil
}

func waitForAgentCollectorPod(t *testing.T, k8sClient *xk8stest.K8sClient, namespace string) string {
	t.Helper()

	var podName string
	require.Eventually(t, func() bool {
		pods, err := k8sClient.DynamicClient.Resource(corev1.SchemeGroupVersion.WithResource("pods")).Namespace(namespace).List(context.Background(), metav1.ListOptions{
			LabelSelector: "component=agent-collector",
		})
		require.NoError(t, err)
		if len(pods.Items) == 0 {
			return false
		}
		for _, pod := range pods.Items {
			status, ok := pod.Object["status"].(map[string]any)
			if !ok {
				continue
			}
			phase, _ := status["phase"].(string)
			if phase == string(corev1.PodRunning) {
				podName = pod.GetName()
				return true
			}
		}
		return false
	}, 2*time.Minute, 2*time.Second, "agent collector pod not ready")

	require.NotEmpty(t, podName, "failed to find running agent collector pod")
	return podName
}

func agentCollectorNamespace() string {
	if ns := os.Getenv("E2E_AGENT_NAMESPACE"); ns != "" {
		return ns
	}
	return "default"
}

func agentServiceName() string {
	if name := os.Getenv("E2E_AGENT_SERVICE"); name != "" {
		return name
	}
	return "coralogix-opentelemetry"
}

func startPortForward(t *testing.T, kubeconfigPath, namespace, resource string, remotePort int) (int, func()) {
	t.Helper()

	localPort := getFreePort(t)
	t.Logf("Starting kubectl port-forward for %s in namespace=%s remotePort=%d localPort=%d", resource, namespace, remotePort, localPort)
	args := []string{
		"--namespace", namespace,
		"port-forward",
		"--address", "127.0.0.1",
		resource,
		fmt.Sprintf("%d:%d", localPort, remotePort),
	}

	ctx, cancel := context.WithCancel(context.Background())
	cmd := exec.CommandContext(ctx, "kubectl", args...)
	if kubeconfigPath != "" {
		cmd.Env = append(os.Environ(), fmt.Sprintf("KUBECONFIG=%s", kubeconfigPath))
	}

	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = &output

	require.NoError(t, cmd.Start(), "failed to start kubectl port-forward: %s", output.String())

	doneCh := make(chan error, 1)
	go func() {
		doneCh <- cmd.Wait()
	}()

	waitForLocalPort(t, localPort, doneCh, &output)
	t.Logf("kubectl port-forward ready on 127.0.0.1:%d", localPort)

	monitorCtx, monitorCancel := context.WithCancel(context.Background())
	var (
		mu             sync.Mutex
		portForwardErr error
	)
	go func() {
		select {
		case err := <-doneCh:
			if ctx.Err() == context.Canceled || monitorCtx.Err() != nil {
				return
			}
			mu.Lock()
			if err != nil {
				portForwardErr = fmt.Errorf("kubectl port-forward exited unexpectedly: %w | output: %s", err, output.String())
			} else {
				portForwardErr = fmt.Errorf("kubectl port-forward exited unexpectedly without error. Output: %s", output.String())
			}
			mu.Unlock()
		case <-monitorCtx.Done():
		}
	}()

	cleanup := func() {
		monitorCancel()
		cancel()
		<-doneCh
		mu.Lock()
		err := portForwardErr
		mu.Unlock()
		require.NoError(t, err)
	}
	return localPort, cleanup
}

func waitForLocalPort(t *testing.T, port int, done <-chan error, output *bytes.Buffer) {
	t.Helper()
	deadline := time.Now().Add(15 * time.Second)

	for time.Now().Before(deadline) {
		select {
		case err := <-done:
			require.NoErrorf(t, err, "port-forward exited early: %s", output.String())
			return
		default:
		}

		conn, err := net.DialTimeout("tcp", fmt.Sprintf("127.0.0.1:%d", port), 250*time.Millisecond)
		if err == nil {
			conn.Close()
			return
		}
		time.Sleep(150 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for port-forward on port %d: %s", port, output.String())
}

func getFreePort(t *testing.T) int {
	t.Helper()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	defer l.Close()
	return l.Addr().(*net.TCPAddr).Port
}
