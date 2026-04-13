package verify

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestLoadExpectations(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "exp.yaml")
	require.NoError(t, os.WriteFile(path, []byte(`
logs:
  min_count: 5
  required_attributes:
    - cx.application.name
    - host.name
metrics:
  required_labels:
    - cx_application_name
collector_health:
  max_send_failures: 0
`), 0o644))

	exp, err := LoadExpectations(path)
	require.NoError(t, err)
	require.NotNil(t, exp.Logs)
	assert.Equal(t, 5, exp.Logs.MinCount)
	assert.Equal(t, []string{"cx.application.name", "host.name"}, exp.Logs.RequiredAttributes)
	require.NotNil(t, exp.Metrics)
	assert.Equal(t, 1, exp.Metrics.MinCount, "default min_count should be 1 when omitted")
	require.NotNil(t, exp.CollectorHealth)
	assert.Equal(t, 0, exp.CollectorHealth.MaxSendFailures)
	assert.Nil(t, exp.Traces, "missing section should be nil")
}

// dataPrimeRow is a helper to build a fake DataPrime NDJSON response with
// configurable resource attributes.
func dataPrimeRow(resourceAttrs map[string]string) string {
	attrs := map[string]interface{}{}
	for k, v := range resourceAttrs {
		attrs[k] = v
	}
	userData, _ := json.Marshal(map[string]interface{}{
		"resource": map[string]interface{}{
			"attributes": attrs,
		},
	})
	row, _ := json.Marshal(map[string]interface{}{
		"metadata": []interface{}{},
		"labels":   []interface{}{},
		"userData": string(userData),
	})
	return string(row)
}

func TestVerifyExpectations_LogsAllPass(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		// Two rows, both with the required attributes
		fmt.Fprintf(w, `{"result":{"results":[%s,%s]}}`,
			dataPrimeRow(map[string]string{"cx.application.name": "app", "host.name": "h1"}),
			dataPrimeRow(map[string]string{"cx.application.name": "app", "host.name": "h2"}),
		)
	}))
	defer srv.Close()

	cfg := Config{
		Client: newTestClient(srv), RunID: "run1",
		Since: time.Now().Add(-1 * time.Hour), Timeout: 30 * time.Second, InitialDelay: 0,
	}
	exp := &Expectations{
		Logs: &SignalExpectation{
			MinCount:           1,
			RequiredAttributes: []string{"cx.application.name", "host.name"},
		},
	}

	r := VerifyExpectations(context.Background(), cfg, exp)
	assert.True(t, r.Pass, "result: %+v", r)
	require.Len(t, r.Sections, 1)
	assert.Equal(t, "logs", r.Sections[0].Name)
	assert.True(t, r.Sections[0].Pass)
}

func TestVerifyExpectations_LogsMissingAttribute(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		// Row missing host.name
		fmt.Fprintf(w, `{"result":{"results":[%s]}}`,
			dataPrimeRow(map[string]string{"cx.application.name": "app"}),
		)
	}))
	defer srv.Close()

	cfg := Config{
		Client: newTestClient(srv), RunID: "run1",
		Since: time.Now().Add(-1 * time.Hour), Timeout: 5 * time.Second, InitialDelay: 0,
	}
	exp := &Expectations{
		Logs: &SignalExpectation{
			MinCount:           1,
			RequiredAttributes: []string{"cx.application.name", "host.name"},
		},
	}

	r := VerifyExpectations(context.Background(), cfg, exp)
	assert.False(t, r.Pass)
	summary := r.FailureSummary()
	assert.Contains(t, summary, "required_attribute host.name")
	assert.Contains(t, summary, "missing")
}

func TestVerifyExpectations_LogsBelowMinCount(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		// Always returns 1 row, but min_count is 5
		fmt.Fprintf(w, `{"result":{"results":[%s]}}`,
			dataPrimeRow(map[string]string{"cx.application.name": "app"}),
		)
	}))
	defer srv.Close()

	cfg := Config{
		Client: newTestClient(srv), RunID: "run1",
		Since: time.Now().Add(-1 * time.Hour), Timeout: 2 * time.Second, InitialDelay: 0,
	}
	exp := &Expectations{
		Logs: &SignalExpectation{MinCount: 5},
	}

	r := VerifyExpectations(context.Background(), cfg, exp)
	assert.False(t, r.Pass)
	assert.Contains(t, r.FailureSummary(), "min_count >= 5")
}

func TestVerifyExpectations_MetricsAllPass(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{
			"status":"success",
			"data":{"resultType":"vector","result":[
				{"metric":{"__name__":"system_cpu","cx_application_name":"otel","host_name":"h1"},"value":[1,"1"]},
				{"metric":{"__name__":"system_mem","cx_application_name":"otel","host_name":"h1"},"value":[1,"2"]}
			]}
		}`))
	}))
	defer srv.Close()

	cfg := Config{
		Client: newTestClient(srv), RunID: "run1",
		Since: time.Now().Add(-1 * time.Hour), Timeout: 5 * time.Second, InitialDelay: 0,
	}
	exp := &Expectations{
		Metrics: &SignalExpectation{
			MinCount:       1,
			RequiredLabels: []string{"cx_application_name", "host_name"},
		},
	}

	r := VerifyExpectations(context.Background(), cfg, exp)
	assert.True(t, r.Pass, "summary: %s", r.FailureSummary())
}

func TestVerifyExpectations_MetricsMissingLabel(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		// host_name is missing on second series
		_, _ = w.Write([]byte(`{
			"status":"success",
			"data":{"resultType":"vector","result":[
				{"metric":{"__name__":"x","cx_application_name":"otel","host_name":"h1"},"value":[1,"1"]},
				{"metric":{"__name__":"y","cx_application_name":"otel"},"value":[1,"2"]}
			]}
		}`))
	}))
	defer srv.Close()

	cfg := Config{
		Client: newTestClient(srv), RunID: "run1",
		Since: time.Now().Add(-1 * time.Hour), Timeout: 5 * time.Second, InitialDelay: 0,
	}
	exp := &Expectations{
		Metrics: &SignalExpectation{
			MinCount:       1,
			RequiredLabels: []string{"cx_application_name", "host_name"},
		},
	}

	r := VerifyExpectations(context.Background(), cfg, exp)
	assert.False(t, r.Pass)
	summary := r.FailureSummary()
	assert.Contains(t, summary, "required_label host_name")
}

func TestVerifyExpectations_CollectorHealthClean(t *testing.T) {
	// PromQL returns empty result = no failures recorded
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"status":"success","data":{"resultType":"vector","result":[]}}`))
	}))
	defer srv.Close()

	cfg := Config{
		Client: newTestClient(srv), RunID: "run1",
		Since: time.Now(), Timeout: 5 * time.Second, InitialDelay: 0,
	}
	exp := &Expectations{
		CollectorHealth: &CollectorHealthCheck{MaxSendFailures: 0},
	}

	r := VerifyExpectations(context.Background(), cfg, exp)
	assert.True(t, r.Pass)
}

func TestVerifyExpectations_CollectorHealthFails(t *testing.T) {
	// PromQL returns a series with value=42 → exceeds max=0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{
			"status":"success",
			"data":{"resultType":"vector","result":[{"metric":{},"value":[1,"42"]}]}
		}`))
	}))
	defer srv.Close()

	cfg := Config{
		Client: newTestClient(srv), RunID: "run1",
		Since: time.Now(), Timeout: 5 * time.Second, InitialDelay: 0,
	}
	exp := &Expectations{
		CollectorHealth: &CollectorHealthCheck{MaxSendFailures: 0},
	}

	r := VerifyExpectations(context.Background(), cfg, exp)
	assert.False(t, r.Pass)
	assert.Contains(t, r.FailureSummary(), "42 failures")
}

func TestVerifyExpectations_CombinedFailureSummary(t *testing.T) {
	// Logs missing attr + metrics below count → both should appear in summary
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost { // DataPrime
			fmt.Fprintf(w, `{"result":{"results":[%s]}}`,
				dataPrimeRow(map[string]string{"only.this": "x"}))
		} else { // PromQL
			_, _ = w.Write([]byte(`{"status":"success","data":{"resultType":"vector","result":[]}}`))
		}
	}))
	defer srv.Close()

	cfg := Config{
		Client: newTestClient(srv), RunID: "run1",
		Since: time.Now().Add(-1 * time.Hour), Timeout: 2 * time.Second, InitialDelay: 0,
	}
	exp := &Expectations{
		Logs:    &SignalExpectation{MinCount: 1, RequiredAttributes: []string{"cx.application.name"}},
		Metrics: &SignalExpectation{MinCount: 5},
	}

	r := VerifyExpectations(context.Background(), cfg, exp)
	assert.False(t, r.Pass)
	summary := r.FailureSummary()
	assert.True(t, strings.Contains(summary, "required_attribute"), "should mention required_attribute, got: %s", summary)
	assert.True(t, strings.Contains(summary, "min_count"), "should mention min_count, got: %s", summary)
}
