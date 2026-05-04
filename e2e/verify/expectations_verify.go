package verify

import (
	"context"
	"fmt"
	"strings"
	"time"
)

// ExpectationResult is the outcome of running one Expectations against CX.
// It is the structured equivalent of "did this E2E run pass?".
type ExpectationResult struct {
	RunID    string         `json:"run_id"`
	Domain   string         `json:"domain"`
	Sections []SectionResult `json:"sections"`
	Pass     bool           `json:"pass"`
}

// SectionResult is the outcome of one section of the expectations file
// (one of: logs, traces, metrics, collector_health).
type SectionResult struct {
	Name     string        `json:"name"`               // "logs" | "traces" | "metrics" | "collector_health"
	Pass     bool          `json:"pass"`
	Checks   []CheckResult `json:"checks"`
	Elapsed  time.Duration `json:"elapsed"`
}

// CheckResult is one assertion within a section (e.g., "min_count >= 5",
// "required_attribute cx.application.name").
type CheckResult struct {
	Name    string `json:"name"`
	Pass    bool   `json:"pass"`
	Detail  string `json:"detail,omitempty"`
}

// VerifyExpectations runs all checks defined in the Expectations against CX.
// Polls each signal section with the same backoff/timeout strategy as the
// existing VerifyLogs/VerifyTraces/VerifyMetrics; once enough data arrives
// to satisfy MinCount, runs the per-record assertions on the returned rows.
func VerifyExpectations(ctx context.Context, cfg Config, exp *Expectations) ExpectationResult {
	cfg.Defaults()

	res := ExpectationResult{
		RunID:  cfg.RunID,
		Domain: cfg.Client.Domain,
		Pass:   true,
	}

	if exp.Logs != nil {
		section := verifyDataPrimeSection(ctx, cfg, "logs",
			fmt.Sprintf("source logs | filter %s | limit 100",
				substituteRunID(cfg.LogsFilter, cfg.RunID)),
			exp.Logs)
		res.Sections = append(res.Sections, section)
		if !section.Pass {
			res.Pass = false
		}
	}

	if exp.Traces != nil {
		section := verifyDataPrimeSection(ctx, cfg, "traces",
			fmt.Sprintf("source spans | filter %s | limit 100",
				substituteRunID(cfg.TracesFilter, cfg.RunID)),
			exp.Traces)
		res.Sections = append(res.Sections, section)
		if !section.Pass {
			res.Pass = false
		}
	}

	if exp.Metrics != nil {
		section := verifyMetricsSection(ctx, cfg,
			substituteRunID(cfg.MetricsFilter, cfg.RunID),
			exp.Metrics)
		res.Sections = append(res.Sections, section)
		if !section.Pass {
			res.Pass = false
		}
	}

	if exp.CollectorHealth != nil {
		section := verifyCollectorHealth(ctx, cfg, exp.CollectorHealth)
		res.Sections = append(res.Sections, section)
		if !section.Pass {
			res.Pass = false
		}
	}

	return res
}

// verifyDataPrimeSection polls a DataPrime query until min_count rows arrive
// (or timeout), then runs required_attributes assertions on the rows.
func verifyDataPrimeSection(ctx context.Context, cfg Config, name, query string, exp *SignalExpectation) SectionResult {
	start := time.Now()
	sec := SectionResult{Name: name}

	pollCtx, cancel := context.WithTimeout(ctx, cfg.Timeout)
	defer cancel()

	if !sleep(pollCtx, cfg.InitialDelay) {
		sec.Checks = append(sec.Checks, CheckResult{
			Name: "min_count", Pass: false, Detail: "context canceled during initial delay",
		})
		sec.Elapsed = time.Since(start)
		return sec
	}

	var lastResult *DataPrimeResult
	var lastErr error
	deadline := time.Now().Add(cfg.Timeout)

	for backoff := 10 * time.Second; ; {
		dpResult, err := cfg.Client.QueryDataPrime(pollCtx, query, cfg.Since)
		if err != nil {
			lastErr = err
		} else {
			lastResult = dpResult
			if dpResult.Count >= exp.MinCount {
				break // enough data, run assertions
			}
		}

		if time.Now().Add(backoff).After(deadline) {
			break // timed out
		}
		if !sleep(pollCtx, backoff) {
			break // context canceled
		}
		backoff *= 2
		if backoff > 60*time.Second {
			backoff = 60 * time.Second
		}
	}

	sec.Elapsed = time.Since(start)

	// min_count check
	if lastResult == nil {
		sec.Checks = append(sec.Checks, CheckResult{
			Name: "min_count", Pass: false,
			Detail: fmt.Sprintf("no successful query: %v", lastErr),
		})
		return sec
	}

	mc := CheckResult{Name: fmt.Sprintf("min_count >= %d", exp.MinCount)}
	if lastResult.Count >= exp.MinCount {
		mc.Pass = true
		mc.Detail = fmt.Sprintf("got %d rows", lastResult.Count)
	} else {
		mc.Detail = fmt.Sprintf("got %d rows after %s", lastResult.Count, sec.Elapsed.Round(time.Second))
	}
	sec.Checks = append(sec.Checks, mc)

	// required_attributes — every row must have all required attributes
	if len(exp.RequiredAttributes) > 0 && lastResult.Count > 0 {
		for _, attr := range exp.RequiredAttributes {
			missing := 0
			for _, row := range lastResult.Rows {
				ra := row.ResourceAttributes()
				if _, ok := ra[attr]; !ok {
					missing++
				}
			}
			cr := CheckResult{Name: fmt.Sprintf("required_attribute %s", attr)}
			if missing == 0 {
				cr.Pass = true
				cr.Detail = fmt.Sprintf("present on all %d rows", len(lastResult.Rows))
			} else {
				cr.Detail = fmt.Sprintf("missing on %d/%d rows", missing, len(lastResult.Rows))
			}
			sec.Checks = append(sec.Checks, cr)
		}
	}

	// Section passes only if every check passes
	sec.Pass = true
	for _, c := range sec.Checks {
		if !c.Pass {
			sec.Pass = false
			break
		}
	}
	return sec
}

// verifyMetricsSection polls PromQL for matching series until min_count is
// reached, then checks required_labels are present on every series.
func verifyMetricsSection(ctx context.Context, cfg Config, query string, exp *SignalExpectation) SectionResult {
	start := time.Now()
	sec := SectionResult{Name: "metrics"}

	pollCtx, cancel := context.WithTimeout(ctx, cfg.Timeout)
	defer cancel()

	if !sleep(pollCtx, cfg.InitialDelay) {
		sec.Checks = append(sec.Checks, CheckResult{
			Name: "min_count", Pass: false, Detail: "context canceled during initial delay",
		})
		sec.Elapsed = time.Since(start)
		return sec
	}

	var lastResult *PromQLResult
	var lastErr error
	deadline := time.Now().Add(cfg.Timeout)

	for backoff := 10 * time.Second; ; {
		pqResult, err := cfg.Client.QueryPromQL(pollCtx, query)
		if err != nil {
			lastErr = err
		} else {
			lastResult = pqResult
			if pqResult.Count >= exp.MinCount {
				break
			}
		}
		if time.Now().Add(backoff).After(deadline) {
			break
		}
		if !sleep(pollCtx, backoff) {
			break
		}
		backoff *= 2
		if backoff > 60*time.Second {
			backoff = 60 * time.Second
		}
	}

	sec.Elapsed = time.Since(start)

	if lastResult == nil {
		sec.Checks = append(sec.Checks, CheckResult{
			Name: "min_count", Pass: false,
			Detail: fmt.Sprintf("no successful query: %v", lastErr),
		})
		return sec
	}

	mc := CheckResult{Name: fmt.Sprintf("min_count >= %d", exp.MinCount)}
	if lastResult.Count >= exp.MinCount {
		mc.Pass = true
		mc.Detail = fmt.Sprintf("got %d series", lastResult.Count)
	} else {
		mc.Detail = fmt.Sprintf("got %d series after %s", lastResult.Count, sec.Elapsed.Round(time.Second))
	}
	sec.Checks = append(sec.Checks, mc)

	// required_labels — every series must have all required labels
	if len(exp.RequiredLabels) > 0 && lastResult.Count > 0 {
		for _, label := range exp.RequiredLabels {
			missing := 0
			for _, s := range lastResult.Series {
				if _, ok := s.Metric[label]; !ok {
					missing++
				}
			}
			cr := CheckResult{Name: fmt.Sprintf("required_label %s", label)}
			if missing == 0 {
				cr.Pass = true
				cr.Detail = fmt.Sprintf("present on all %d series", len(lastResult.Series))
			} else {
				cr.Detail = fmt.Sprintf("missing on %d/%d series", missing, len(lastResult.Series))
			}
			sec.Checks = append(sec.Checks, cr)
		}
	}

	sec.Pass = true
	for _, c := range sec.Checks {
		if !c.Pass {
			sec.Pass = false
			break
		}
	}
	return sec
}

// verifyCollectorHealth queries PromQL for otelcol_exporter_send_failed_records_total
// scoped to this run_id and asserts the sum is <= max_send_failures.
func verifyCollectorHealth(ctx context.Context, cfg Config, exp *CollectorHealthCheck) SectionResult {
	start := time.Now()
	sec := SectionResult{Name: "collector_health"}

	// sum(otelcol_exporter_send_failed_records_total{e2e_run_id="<id>"})
	// We sum across all exporters/data_types so the threshold is total failures.
	query := fmt.Sprintf(`sum(otelcol_exporter_send_failed_records_total{e2e_run_id=%q})`, cfg.RunID)

	pollCtx, cancel := context.WithTimeout(ctx, cfg.Timeout)
	defer cancel()

	pqResult, err := cfg.Client.QueryPromQL(pollCtx, query)
	sec.Elapsed = time.Since(start)

	cr := CheckResult{Name: fmt.Sprintf("max_send_failures <= %d", exp.MaxSendFailures)}
	if err != nil {
		cr.Detail = fmt.Sprintf("query error: %v", err)
		sec.Checks = []CheckResult{cr}
		return sec
	}

	// Empty result = no failures recorded yet (collector never failed to send).
	// That's a pass.
	if len(pqResult.Series) == 0 {
		cr.Pass = true
		cr.Detail = "no send failures recorded"
	} else {
		val := pqResult.Series[0].MetricValue()
		if int(val) <= exp.MaxSendFailures {
			cr.Pass = true
			cr.Detail = fmt.Sprintf("got %.0f failures", val)
		} else {
			cr.Detail = fmt.Sprintf("got %.0f failures (limit %d)", val, exp.MaxSendFailures)
		}
	}

	sec.Checks = []CheckResult{cr}
	sec.Pass = cr.Pass
	return sec
}

// FailureSummary returns a multi-line human-readable description of failed
// checks across all sections, suitable for printing to stderr on test failure.
// Returns empty string if nothing failed.
func (r ExpectationResult) FailureSummary() string {
	var b strings.Builder
	for _, sec := range r.Sections {
		for _, c := range sec.Checks {
			if !c.Pass {
				b.WriteString(fmt.Sprintf("  %s.%s: %s\n", sec.Name, c.Name, c.Detail))
			}
		}
	}
	return b.String()
}
