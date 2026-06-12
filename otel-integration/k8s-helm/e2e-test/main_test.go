// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

package e2e

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/davecgh/go-spew/spew"
	"github.com/google/uuid"
	"github.com/open-telemetry/opentelemetry-collector-contrib/pkg/xk8stest"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/consumer/consumertest"
	"go.opentelemetry.io/collector/pdata/pcommon"
	"go.opentelemetry.io/collector/pdata/plog"
	"go.opentelemetry.io/collector/pdata/pmetric"
	"go.opentelemetry.io/collector/pdata/ptrace"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apimachinery/pkg/runtime/serializer/yaml"
)

const (
	testKubeConfig   = "/tmp/kind-otel-integration-agent-e2e"
	kubeConfigEnvVar = "KUBECONFIG"

	serviceNameAttribute = "service.name"
)

type agentScenarioResult struct {
	logs      []plog.Logs
	metrics   []pmetric.Metrics
	traces    []ptrace.Traces
	namespace string
	testID    string
}

var (
	agentScenarioMu     sync.Mutex
	cachedAgentScenario *agentScenarioResult
)

func TestE2E_Agent(t *testing.T) {
	scenario := getAgentScenario(t)

	checkSystemLogsAttributes(t, scenario.logs)
	checkResourceMetrics(t, scenario.metrics)
	checkTracesAttributes(t, scenario.traces, scenario.testID, scenario.namespace)
}

func getAgentScenario(t *testing.T) agentScenarioResult {
	t.Helper()

	agentScenarioMu.Lock()
	defer agentScenarioMu.Unlock()

	if cachedAgentScenario != nil {
		return *cachedAgentScenario
	}

	scenario := collectAgentScenario(t)
	cachedAgentScenario = &scenario
	return scenario
}

func collectAgentScenario(t *testing.T) agentScenarioResult {
	t.Helper()

	require.Equal(t, xk8stest.HostEndpoint(t), os.Getenv("HOSTENDPOINT"), "HostEndpoints does not match env and detected")

	testDataDir := filepath.Join("testdata")

	kubeconfigPath := testKubeConfig
	if kubeConfigFromEnv := os.Getenv(kubeConfigEnvVar); kubeConfigFromEnv != "" {
		kubeconfigPath = kubeConfigFromEnv
	}

	k8sClient, err := xk8stest.NewK8sClient(kubeconfigPath)
	require.NoError(t, err)

	nsFile := filepath.Join(testDataDir, "namespace.yaml")
	buf, err := os.ReadFile(nsFile)
	require.NoErrorf(t, err, "failed to read namespace object file %s", nsFile)
	ensureNamespaceIsClean(t, k8sClient, buf, nsFile)
	nsObj, err := xk8stest.CreateObject(k8sClient, buf)
	require.NoErrorf(t, err, "failed to create k8s namespace from file %s", nsFile)

	testNs := nsObj.GetName()

	podFile := filepath.Join(testDataDir, "pod.yaml")
	buf, err = os.ReadFile(podFile)
	require.NoErrorf(t, err, "failed to read pod object file %s", podFile)
	podObj, err := xk8stest.CreateObject(k8sClient, buf)
	require.NoErrorf(t, err, "failed to create k8s pod from file %s", podFile)
	require.Eventually(t, func() bool {
		pod, err := k8sClient.DynamicClient.Resource(corev1.SchemeGroupVersion.WithResource("pods")).Namespace(testNs).Get(context.Background(), podObj.GetName(), metav1.GetOptions{})
		return err == nil && pod.Object["status"].(map[string]interface{})["phase"] == string(corev1.PodRunning)
	}, time.Minute, time.Second)
	xk8stest.DeleteObject(k8sClient, podObj)

	metricsConsumer := new(consumertest.MetricsSink)
	tracesConsumer := new(consumertest.TracesSink)
	logsConsumer := new(consumertest.LogsSink)

	shutdownSink := StartUpSinks(t, ReceiverSinks{
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
		Logs: &LogSinkConfig{
			Consumer: logsConsumer,
			Ports: &ReceiverPorts{
				Grpc: 4323,
			},
		},
	})
	defer shutdownSink()

	testID := uuid.NewString()[:8]
	createTeleOpts := &xk8stest.TelemetrygenCreateOpts{
		ManifestsDir: filepath.Join(testDataDir, "telemetrygen"),
		TestID:       testID,
		DataTypes:    []string{"traces"},
	}

	telemetryGenObjs, telemetryGenObjInfos := xk8stest.CreateTelemetryGenObjects(t, k8sClient, createTeleOpts)
	for _, info := range telemetryGenObjInfos {
		xk8stest.WaitForTelemetryGenToStart(t, k8sClient, info.Namespace, info.PodLabelSelectors, info.Workload, info.DataType)
	}

	t.Cleanup(func() {
		require.NoErrorf(t, xk8stest.DeleteObject(k8sClient, nsObj), "failed to delete namespace %s", testNs)
		for _, obj := range telemetryGenObjs {
			require.NoErrorf(t, xk8stest.DeleteObject(k8sClient, obj), "failed to delete object %s", obj.GetName())
		}
	})

	waitForLogs(t, 1, logsConsumer)
	waitForMetrics(t, 20, metricsConsumer)
	waitForTraces(t, 10, tracesConsumer)

	return agentScenarioResult{
		logs:      cloneLogs(logsConsumer.AllLogs()),
		metrics:   cloneMetrics(metricsConsumer.AllMetrics()),
		traces:    cloneTraces(tracesConsumer.AllTraces()),
		namespace: testNs,
		testID:    testID,
	}
}

func ensureNamespaceIsClean(t *testing.T, client *xk8stest.K8sClient, manifest []byte, manifestPath string) {
	t.Helper()

	nsObj := decodeManifestObject(t, manifest, manifestPath)
	nsName := nsObj.GetName()

	namespacesRes := schema.GroupVersionResource{Group: "", Version: "v1", Resource: "namespaces"}
	_, err := client.DynamicClient.Resource(namespacesRes).
		Get(context.Background(), nsName, metav1.GetOptions{})
	if err != nil {
		if apierrors.IsNotFound(err) {
			return
		}
		require.NoErrorf(t, err, "failed to inspect existing namespace %s", nsName)
	}

	err = xk8stest.DeleteObject(client, nsObj)
	if err != nil && !apierrors.IsNotFound(err) {
		require.NoErrorf(t, err, "failed to delete existing namespace %s", nsName)
	}

	require.Eventually(t, func() bool {
		_, err := client.DynamicClient.Resource(namespacesRes).
			Get(context.Background(), nsName, metav1.GetOptions{})
		return apierrors.IsNotFound(err)
	}, 2*time.Minute, 2*time.Second, "namespace %s still terminating", nsName)
}

func decodeManifestObject(t *testing.T, manifest []byte, manifestPath string) *unstructured.Unstructured {
	t.Helper()

	obj := &unstructured.Unstructured{}
	decoder := yaml.NewDecodingSerializer(unstructured.UnstructuredJSONScheme)
	_, _, err := decoder.Decode(manifest, nil, obj)
	require.NoErrorf(t, err, "failed to decode manifest object from %s", manifestPath)

	return obj
}

func cloneMetrics(input []pmetric.Metrics) []pmetric.Metrics {
	copied := make([]pmetric.Metrics, len(input))
	for i := range input {
		copied[i] = pmetric.NewMetrics()
		input[i].CopyTo(copied[i])
	}
	return copied
}

func cloneTraces(input []ptrace.Traces) []ptrace.Traces {
	copied := make([]ptrace.Traces, len(input))
	for i := range input {
		copied[i] = ptrace.NewTraces()
		input[i].CopyTo(copied[i])
	}
	return copied
}

func cloneLogs(input []plog.Logs) []plog.Logs {
	copied := make([]plog.Logs, len(input))
	for i := range input {
		copied[i] = plog.NewLogs()
		input[i].CopyTo(copied[i])
	}
	return copied
}

func checkResourceMetrics(t *testing.T, actual []pmetric.Metrics) error {
	if len(actual) == 0 {
		t.Fatal("metrics: No resource metrics received")
	}

	observedSchemaURLs := map[string]struct{}{}
	foundExpectedSchema := false
	for _, current := range actual {
		actualMetrics := pmetric.NewMetrics()
		current.CopyTo(actualMetrics)

		for i := 0; i < actualMetrics.ResourceMetrics().Len(); i++ {
			rmetrics := actualMetrics.ResourceMetrics().At(i)
			observedSchemaURLs[rmetrics.SchemaUrl()] = struct{}{}

			if _, ok := expectedResourceMetricsSchemaURL[rmetrics.SchemaUrl()]; ok {
				expectedResourceMetricsSchemaURL[rmetrics.SchemaUrl()] = true
				foundExpectedSchema = true
			}

			checkScopeMetrics(t, rmetrics)
		}
	}

	if !foundExpectedSchema {
		t.Fatalf(
			"metrics: none of the expected schema_url values were found (expected one of: %s, observed: %s)",
			strings.Join(expectedSchemaURLs(), ", "),
			strings.Join(sortedSchemaURLs(observedSchemaURLs), ", "),
		)
	}
	for name, expectedState := range expectedResourceScopeNames {
		require.True(t, expectedState, "metrics: scope %v was not found in the actual metrics, found scope names: %v", name, expectedResourceScopeNames)
	}

	var missingMetrics []string
	for name, expectedState := range expectedMetrics {
		if !expectedState {
			missingMetrics = append(missingMetrics, name)
		}
	}

	if len(missingMetrics) > 0 {
		// Note: actual metrics should a subset of expected metrics,
		// and some expected metrics may not be found in actual metrics
		t.Fatalf("expected metrics %v were not found in the actual metrics", missingMetrics)
	}

	return nil
}

func expectedSchemaURLs() []string {
	urls := make([]string, 0, len(expectedResourceMetricsSchemaURL))
	for url := range expectedResourceMetricsSchemaURL {
		urls = append(urls, url)
	}
	sort.Strings(urls)
	return urls
}

func sortedSchemaURLs(urls map[string]struct{}) []string {
	out := make([]string, 0, len(urls))
	for url := range urls {
		out = append(out, url)
	}
	sort.Strings(out)
	return out
}

func checkScopeMetrics(t *testing.T, rmetrics pmetric.ResourceMetrics) error {

	for k := 0; k < rmetrics.ScopeMetrics().Len(); k++ {
		scope := rmetrics.ScopeMetrics().At(k)

		// Ignore checking telemetrygen resource metrics (e.g. "gen")
		if len(scope.Scope().Name()) == 0 && len(scope.Scope().Version()) == 0 {
			continue
		}

		// Break if unwanted scope detected (e.g. spanmetrics)
		_, exist := unwantedScopeNames[scope.Scope().Name()]
		if exist {
			t.Fatalf("unwanted scope detected %v", scope.Scope().Name())
		}

		scopeName := scope.Scope().Name()
		_, ok := expectedResourceScopeNames[scopeName]
		if ok {
			expectedResourceScopeNames[scopeName] = true
		} else if _, optional := optionalScopeNames[scopeName]; optional {
			ok = true
		}

		if !ok {
			for k := 0; k < rmetrics.ScopeMetrics().Len(); k++ {
				scope := rmetrics.ScopeMetrics().At(k)
				fmt.Printf("found scopeName: %v\n", scope.Scope().Name())
			}
		}
		require.True(t, ok, "metrics: scope %v does not match one of the expected values", scope.Scope().Name())

		// We only need the relevant part of the scopr name to get receiver name.
		scopeNameTrimmed := strings.Split(scope.Scope().Name(), "/")
		checkResourceAttributes(t, rmetrics.Resource().Attributes(), scopeNameTrimmed[len(scopeNameTrimmed)-1])

		metrics := scope.Metrics()

		for j := 0; j < metrics.Len(); j++ {
			metric := metrics.At(j)

			_, ok := expectedMetrics[metric.Name()]
			if ok {
				expectedMetrics[metric.Name()] = true
			} else if _, optional := optionalExpectedMetrics[metric.Name()]; optional {
				optionalExpectedMetrics[metric.Name()] = true
				ok = true
			}
			if !ok {
				spew.Dump(metric)
				for j := 0; j < metrics.Len(); j++ {
					metric := metrics.At(j)
					fmt.Printf("Found metric %s\n", metric.Name())
				}
			}
			require.True(t, ok, "actual metrics detected %v do not match expected metrics", metric.Name())
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
	case "k8sattributesprocessor":
		compareMap = expectedResourceAttributesK8sattributesprocessor
	case "loadscraper":
		compareMap = expectedResourceAttributesLoadscraper
	case "memorylimiterprocessor":
		compareMap = expectedResourceAttributesMemorylimiterprocessor
	case "processscraper":
		compareMap = expectedResourceAttributesProcessscraper
	case "service":
		compareMap = expectedResourceAttributesService
	case "processorhelper":
		compareMap = expectedResourceAttributesProcessorhelper
	case "spanmetricsconnector":
		compareMap = expectedResourceAttributesSpanmetricsconnector
	case "delta-to-cumulative-e2e":
		compareMap = expectedResourceAttributesDeltaToCumulative
	default:
		compareMap = expectedResourceAttributesMemorylimiterprocessor
	}

	attributes.Range(func(k string, v pcommon.Value) bool {
		val, ok := compareMap[k]
		if !ok {
			attributes.Range(func(k string, v pcommon.Value) bool {
				fmt.Printf("found attribute: scopeName: %s, attribute: %v\n", scopeName, k)
				return true
			})
		}
		require.True(t, ok, "metrics: unexpected attribute %v - scopeName: %s", k, scopeName)
		if val != "" {
			require.Equal(t, val, v.AsString(), "metrics: unexpected value for attribute %v - scopeName: %s", k, scopeName)
		}
		return true
	})

	return nil
}

func checkTracesAttributes(t *testing.T, actual []ptrace.Traces, testID string, testNs string) error {
	if len(actual) == 0 {
		t.Fatal("No traces received")
	}

	for _, current := range actual {
		trace := ptrace.NewTraces()
		current.CopyTo(trace)

		for i := 0; i < trace.ResourceSpans().Len(); i++ {
			rspans := trace.ResourceSpans().At(i)

			_, ok := expectedTracesSchemaURL[rspans.SchemaUrl()]
			require.True(t, ok, "traces: resource %v does not match one of the expected values", rspans.SchemaUrl())
			if ok {
				expectedTracesSchemaURL[rspans.SchemaUrl()] = true
			}

			resource := rspans.Resource()
			service, exist := resource.Attributes().Get(serviceNameAttribute)

			expectedTrace := expectedTraces(testID, testNs)[service.AsString()]
			require.NotEmpty(t, expectedTrace, "traces: unexpected service name %v", service.AsString())
			require.True(t, exist, "traces: resource does not have the 'service.name' attribute")
			assert.NoError(t, assertExpectedAttributes(resource.Attributes(), expectedTrace.attrs))

			require.NotZero(t, rspans.ScopeSpans().Len())
			require.NotZero(t, rspans.ScopeSpans().At(0).Spans().Len())
		}
	}
	return nil
}

func assertExpectedAttributes(attrs pcommon.Map, kvs map[string]expectedValue) error {
	foundAttrs := make(map[string]bool)
	for k, v := range kvs {
		// Optional attributes are considered found by default
		if v.mode == attributeMatchTypeOptional || v.mode == attributeMatchTypeOptionalRegex {
			foundAttrs[k] = true
		} else {
			foundAttrs[k] = false
		}
	}
	var notFoundAttrs []string

	attrs.Range(func(k string, v pcommon.Value) bool {
		if val, ok := kvs[k]; ok {
			switch val.mode {
			case attributeMatchTypeEqual:
				if val.value == v.AsString() {
					foundAttrs[k] = true
				} else {
					fmt.Printf("attribute %s expected %q got %q\n", k, val.value, v.AsString())
				}
			case attributeMatchTypeRegex:
				matched, _ := regexp.MatchString(val.value, v.AsString())
				if matched {
					foundAttrs[k] = true
				} else {
					fmt.Printf("attribute %s regex %q did not match %q\n", k, val.value, v.AsString())
				}
			case attributeMatchTypeExist:
				foundAttrs[k] = true
			case attributeMatchTypeOptional:
				// Attribute exists and is optional, so it's valid
				foundAttrs[k] = true
			case attributeMatchTypeOptionalRegex:
				// Attribute exists and is optional, validate regex if provided
				if val.value == "" {
					foundAttrs[k] = true
				} else {
					matched, _ := regexp.MatchString(val.value, v.AsString())
					if matched {
						foundAttrs[k] = true
					} else {
						foundAttrs[k] = false
					}
				}
			}
		} else {
			notFoundAttrs = append(notFoundAttrs, k)
		}
		return true
	})

	var err error
	for k, v := range foundAttrs {
		if !v {
			err = errors.Join(err, fmt.Errorf("attribute '%v' not found", k))
		}
	}
	if err != nil {
		expectedJson, _ := json.MarshalIndent(kvs, "", "  ")
		actualJson, _ := json.MarshalIndent(attrs.AsRaw(), "", "  ")
		err = errors.Join(err, fmt.Errorf("one or more attributes were not found.\nExpected attributes:\n %s \nActual attributes: \n%s", expectedJson, actualJson))
	}

	return err
}

func checkSystemLogsAttributes(t *testing.T, actual []plog.Logs) error {
	if len(actual) == 0 {
		t.Fatal("No logs received")
	}

	foundHostEntityEvent := false

	for _, current := range actual {
		logs := plog.NewLogs()
		current.CopyTo(logs)

		for i := 0; i < logs.ResourceLogs().Len(); i++ {
			rlogs := logs.ResourceLogs().At(i)

			// Validate schema URL
			_, ok := expectedLogsSchemaURL[rlogs.SchemaUrl()]
			require.True(t, ok, "logs: schema_url %v does not match one of the expected values", rlogs.SchemaUrl())
			if ok {
				expectedLogsSchemaURL[rlogs.SchemaUrl()] = true
			}

			require.NotZero(t, rlogs.ScopeLogs().Len())
			require.NotZero(t, rlogs.ScopeLogs().At(0).LogRecords().Len())

			// Check scope logs for host entity events
			for j := 0; j < rlogs.ScopeLogs().Len(); j++ {
				scopeLogs := rlogs.ScopeLogs().At(j)

				// Check individual log records
				for k := 0; k < scopeLogs.LogRecords().Len(); k++ {
					logRecord := scopeLogs.LogRecords().At(k)
					logAttrs := logRecord.Attributes()

					// Check if this is a host entity event
					if entityType, exists := logAttrs.Get("otel.entity.type"); exists && entityType.AsString() == "host" {
						foundHostEntityEvent = true

						// Validate expected host entity attributes using the expected values
						assert.NoError(t, assertExpectedAttributes(logAttrs, expectedHostEntityAttributes))
					}
				}
			}
		}
	}

	// Ensure we found at least one host entity event
	require.True(t, foundHostEntityEvent, "No host entity event found in logs")

	// Verify at least one expected schema URL was found
	foundSchema := false
	for _, expectedState := range expectedLogsSchemaURL {
		if expectedState {
			foundSchema = true
			continue
		}
	}
	if !foundSchema {
		missing := make([]string, 0, len(expectedLogsSchemaURL))
		for name := range expectedLogsSchemaURL {
			missing = append(missing, name)
		}
		require.Failf(t, "logs: schema_url not found", "expected one of %v in the actual logs", missing)
	}

	return nil
}
