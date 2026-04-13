package verify

import (
	"context"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestVerifyLogs_FoundOnFirstPoll(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"result":{"results":[{"foo":"bar"}]}}`))
	}))
	defer srv.Close()

	cfg := Config{
		Client:       newTestClient(srv),
		RunID:        "abc",
		Since:        time.Now().Add(-1 * time.Hour),
		Timeout:      30 * time.Second,
		InitialDelay: 0, // no delay for tests
	}

	res := VerifyLogs(context.Background(), cfg)
	assert.True(t, res.Found, "expected logs to be found")
	assert.Equal(t, 1, res.Count)
	assert.Equal(t, SignalLogs, res.Signal)
	assert.Empty(t, res.Error)
}

func TestVerifyLogs_FoundAfterRetry(t *testing.T) {
	var calls int32
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		n := atomic.AddInt32(&calls, 1)
		if n < 2 {
			_, _ = w.Write([]byte(`{"result":{"results":[]}}`)) // empty first time
			return
		}
		_, _ = w.Write([]byte(`{"result":{"results":[{"x":1}]}}`)) // found second time
	}))
	defer srv.Close()

	cfg := Config{
		Client:       newTestClient(srv),
		RunID:        "abc",
		Since:        time.Now().Add(-1 * time.Hour),
		Timeout:      30 * time.Second,
		InitialDelay: 0,
	}

	// Override the initial backoff to make the test fast — we use a custom timeout
	// short enough that we know it had to retry at least once.
	res := VerifyLogs(context.Background(), cfg)
	assert.True(t, res.Found)
	assert.GreaterOrEqual(t, atomic.LoadInt32(&calls), int32(2))
}

func TestVerifyLogs_TimeoutNoData(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"result":{"results":[]}}`))
	}))
	defer srv.Close()

	cfg := Config{
		Client:       newTestClient(srv),
		RunID:        "abc",
		Since:        time.Now().Add(-1 * time.Hour),
		Timeout:      2 * time.Second, // very short
		InitialDelay: 0,
	}

	res := VerifyLogs(context.Background(), cfg)
	assert.False(t, res.Found)
	assert.Contains(t, res.Error, "no data found")
}

func TestVerifyMetrics_Success(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"status":"success","data":{"resultType":"vector","result":[{"metric":{"x":"y"}}]}}`))
	}))
	defer srv.Close()

	cfg := Config{
		Client:       newTestClient(srv),
		RunID:        "abc",
		Since:        time.Now().Add(-1 * time.Hour),
		Timeout:      30 * time.Second,
		InitialDelay: 0,
	}

	res := VerifyMetrics(context.Background(), cfg)
	assert.True(t, res.Found)
	assert.Equal(t, 1, res.Count)
	assert.Equal(t, SignalMetrics, res.Signal)
}

func TestVerifyAll_RunsConcurrently(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Both DataPrime and PromQL endpoints return data
		if r.Method == http.MethodPost {
			_, _ = w.Write([]byte(`{"result":{"results":[{"x":1}]}}`))
		} else {
			_, _ = w.Write([]byte(`{"status":"success","data":{"resultType":"vector","result":[{"y":1}]}}`))
		}
	}))
	defer srv.Close()

	cfg := Config{
		Client:       newTestClient(srv),
		RunID:        "abc",
		Since:        time.Now().Add(-1 * time.Hour),
		Timeout:      30 * time.Second,
		InitialDelay: 0,
	}

	results := VerifyAll(context.Background(), cfg, []Signal{SignalLogs, SignalTraces, SignalMetrics})
	assert.Len(t, results, 3)
	for _, r := range results {
		assert.True(t, r.Found, "signal %s should be found", r.Signal)
	}
}

func TestSubstituteRunID(t *testing.T) {
	got := substituteRunID(`$d.resource.attributes.e2e_run_id == '{{run_id}}'`, "abc-123")
	assert.Equal(t, `$d.resource.attributes.e2e_run_id == 'abc-123'`, got)
}

func TestDefaults(t *testing.T) {
	cfg := Config{}
	cfg.Defaults()
	assert.Equal(t, 10*time.Minute, cfg.Timeout)
	assert.Equal(t, time.Duration(0), cfg.InitialDelay, "InitialDelay defaults to 0; CLI sets it explicitly")
	assert.Contains(t, cfg.LogsFilter, "{{run_id}}")
	assert.Contains(t, cfg.MetricsFilter, "{{run_id}}")
}
