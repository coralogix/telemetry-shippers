package verify

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"
)

// Signal identifies the telemetry signal to verify.
type Signal string

const (
	SignalLogs    Signal = "logs"
	SignalTraces  Signal = "traces"
	SignalMetrics Signal = "metrics"
)

// Config controls a verification run.
type Config struct {
	Client       *Client       // Coralogix client
	RunID        string        // unique E2E run identifier (must match resource attribute on telemetry)
	Since        time.Time     // earliest timestamp to consider data valid
	Timeout      time.Duration // total time to poll before giving up
	InitialDelay time.Duration // delay before first poll (default 30s)

	// Filter expressions. The string "{{run_id}}" is replaced with cfg.RunID at query time.
	// Defaults are set by Defaults() if empty.
	LogsFilter    string // DataPrime filter clause for logs
	TracesFilter  string // DataPrime filter clause for spans
	MetricsFilter string // PromQL selector for metrics
}

// Defaults fills in zero-value fields with sensible defaults.
// Note: InitialDelay defaults to 0 (immediate first poll). Callers (e.g. the CLI)
// should set it explicitly to give the collector time to flush the first batch.
func (c *Config) Defaults() {
	if c.Timeout == 0 {
		c.Timeout = 10 * time.Minute
	}
	// DataPrime substring match on the entire $d document. This works because:
	//   - OTel resource attribute keys can contain dots (e.g. "e2e.run_id"), but
	//     DataPrime's path access only supports [a-zA-Z0-9_], so structured
	//     access like $d.resource.attributes.e2e_run_id raises "keypath does not exist"
	//   - userData is stored as a JSON-encoded string, not a parsed object
	//   - The run_id value is unique per E2E run, so substring match has no
	//     false-positive risk in practice
	if c.LogsFilter == "" {
		c.LogsFilter = `$d ~~ '{{run_id}}'`
	}
	if c.TracesFilter == "" {
		c.TracesFilter = `$d ~~ '{{run_id}}'`
	}
	// PromQL: OTel resource attributes are mapped to Prometheus labels with
	// dots converted to underscores (e2e.run_id -> e2e_run_id).
	if c.MetricsFilter == "" {
		c.MetricsFilter = `{e2e_run_id="{{run_id}}"}`
	}
}

// Result is the outcome of a single signal verification.
type Result struct {
	Signal  Signal        `json:"signal"`
	Found   bool          `json:"found"`
	Count   int           `json:"count"`
	Sample  string        `json:"sample,omitempty"`
	Elapsed time.Duration `json:"elapsed"`
	Error   string        `json:"error,omitempty"`
}

// VerifyLogs polls DataPrime for logs matching the run ID.
func VerifyLogs(ctx context.Context, cfg Config) Result {
	cfg.Defaults()
	query := fmt.Sprintf("source logs | filter %s | limit 5",
		substituteRunID(cfg.LogsFilter, cfg.RunID))
	return pollDataPrime(ctx, cfg, SignalLogs, query)
}

// VerifyTraces polls DataPrime for spans matching the run ID.
func VerifyTraces(ctx context.Context, cfg Config) Result {
	cfg.Defaults()
	query := fmt.Sprintf("source spans | filter %s | limit 5",
		substituteRunID(cfg.TracesFilter, cfg.RunID))
	return pollDataPrime(ctx, cfg, SignalTraces, query)
}

// VerifyMetrics polls the PromQL endpoint for metrics matching the run ID.
func VerifyMetrics(ctx context.Context, cfg Config) Result {
	cfg.Defaults()
	query := substituteRunID(cfg.MetricsFilter, cfg.RunID)
	return pollPromQL(ctx, cfg, query)
}

// VerifyAll runs the requested checks concurrently and returns all results.
func VerifyAll(ctx context.Context, cfg Config, checks []Signal) []Result {
	results := make([]Result, len(checks))
	var wg sync.WaitGroup
	for i, sig := range checks {
		wg.Add(1)
		go func(i int, sig Signal) {
			defer wg.Done()
			switch sig {
			case SignalLogs:
				results[i] = VerifyLogs(ctx, cfg)
			case SignalTraces:
				results[i] = VerifyTraces(ctx, cfg)
			case SignalMetrics:
				results[i] = VerifyMetrics(ctx, cfg)
			default:
				results[i] = Result{Signal: sig, Error: "unknown signal"}
			}
		}(i, sig)
	}
	wg.Wait()
	return results
}

func substituteRunID(template, runID string) string {
	return strings.ReplaceAll(template, "{{run_id}}", runID)
}

// pollDataPrime polls a DataPrime query with exponential backoff until data
// is found or the timeout expires.
func pollDataPrime(ctx context.Context, cfg Config, sig Signal, query string) Result {
	start := time.Now()
	r := Result{Signal: sig}

	deadline := start.Add(cfg.Timeout)
	pollCtx, cancel := context.WithDeadline(ctx, deadline)
	defer cancel()

	if !sleep(pollCtx, cfg.InitialDelay) {
		r.Error = "context canceled during initial delay"
		r.Elapsed = time.Since(start)
		return r
	}

	for backoff := 10 * time.Second; ; {
		dpResult, err := cfg.Client.QueryDataPrime(pollCtx, query, cfg.Since)
		if err != nil {
			// Log the error but keep polling — transient API failures shouldn't
			// fail the whole verification immediately.
			r.Error = err.Error()
		} else if dpResult.Count > 0 {
			r.Found = true
			r.Count = dpResult.Count
			r.Sample = truncate(dpResult.Sample, 500)
			r.Error = ""
			r.Elapsed = time.Since(start)
			return r
		}

		if time.Now().Add(backoff).After(deadline) {
			r.Elapsed = time.Since(start)
			if r.Error == "" {
				r.Error = fmt.Sprintf("no data found within timeout (%s)", cfg.Timeout)
			}
			return r
		}
		if !sleep(pollCtx, backoff) {
			r.Elapsed = time.Since(start)
			r.Error = "context canceled while waiting"
			return r
		}
		backoff *= 2
		if backoff > 60*time.Second {
			backoff = 60 * time.Second
		}
	}
}

// pollPromQL polls a PromQL query with exponential backoff.
func pollPromQL(ctx context.Context, cfg Config, query string) Result {
	start := time.Now()
	r := Result{Signal: SignalMetrics}

	deadline := start.Add(cfg.Timeout)
	pollCtx, cancel := context.WithDeadline(ctx, deadline)
	defer cancel()

	if !sleep(pollCtx, cfg.InitialDelay) {
		r.Error = "context canceled during initial delay"
		r.Elapsed = time.Since(start)
		return r
	}

	for backoff := 10 * time.Second; ; {
		pqResult, err := cfg.Client.QueryPromQL(pollCtx, query)
		if err != nil {
			r.Error = err.Error()
		} else if pqResult.Count > 0 {
			r.Found = true
			r.Count = pqResult.Count
			r.Sample = truncate(pqResult.Sample, 500)
			r.Error = ""
			r.Elapsed = time.Since(start)
			return r
		}

		if time.Now().Add(backoff).After(deadline) {
			r.Elapsed = time.Since(start)
			if r.Error == "" {
				r.Error = fmt.Sprintf("no metrics found within timeout (%s)", cfg.Timeout)
			}
			return r
		}
		if !sleep(pollCtx, backoff) {
			r.Elapsed = time.Since(start)
			r.Error = "context canceled while waiting"
			return r
		}
		backoff *= 2
		if backoff > 60*time.Second {
			backoff = 60 * time.Second
		}
	}
}

// sleep waits for d or until ctx is canceled. Returns true if d elapsed normally.
func sleep(ctx context.Context, d time.Duration) bool {
	if d <= 0 {
		return true
	}
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-t.C:
		return true
	case <-ctx.Done():
		return false
	}
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "..."
}
