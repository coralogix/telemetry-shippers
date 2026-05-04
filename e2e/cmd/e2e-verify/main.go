// Command e2e-verify polls Coralogix to verify that telemetry data has arrived
// from an E2E test run. It is invoked from CI workflows after the OTel collector
// is deployed and telemetrygen has emitted data.
//
// Usage:
//
//	e2e-verify \
//	  --domain coralogix.com \
//	  --api-key $E2E_CX_LOGS_QUERY_KEY \
//	  --run-id 12345-linux \
//	  --since 2026-04-13T10:00:00Z \
//	  --check logs --check traces --check metrics \
//	  --timeout 10m
//
// On success, prints a JSON summary and exits 0. On any check failure, exits 1.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"coralogix.com/telemetry-shippers/e2e/verify"
)

// stringSlice is a flag.Value that accumulates repeated --check args.
type stringSlice []string

func (s *stringSlice) String() string     { return strings.Join(*s, ",") }
func (s *stringSlice) Set(v string) error { *s = append(*s, v); return nil }

func main() {
	var (
		domain        = flag.String("domain", "", "Coralogix domain (e.g. coralogix.com) [required]")
		apiKey        = flag.String("api-key", "", "Coralogix Logs Query Key (NOT the Send-Your-Data key) [required, or env E2E_CX_LOGS_QUERY_KEY]")
		runID         = flag.String("run-id", "", "Unique E2E run identifier [required]")
		since         = flag.String("since", "", "Earliest data timestamp (RFC3339, e.g. 2026-04-13T10:00:00Z). Overrides --window if set.")
		window        = flag.Duration("window", 24*time.Hour, "Look back this far for data (relative to now). Ignored if --since is set.")
		timeout       = flag.Duration("timeout", 10*time.Minute, "Total polling timeout")
		initialDelay  = flag.Duration("initial-delay", 30*time.Second, "Wait this long before first poll (collector flush time)")
		logsFilter    = flag.String("logs-filter", "", "Override DataPrime filter clause for logs (use {{run_id}} placeholder)")
		tracesFilter  = flag.String("traces-filter", "", "Override DataPrime filter clause for traces (use {{run_id}} placeholder)")
		metricsFilter = flag.String("metrics-filter", "", "Override PromQL selector for metrics (use {{run_id}} placeholder)")
		expectations  = flag.String("expectations", "", "Path to expectations YAML. When set, runs structured expectation checks instead of --check flags.")
	)
	var checks stringSlice
	flag.Var(&checks, "check", "Signal to verify: logs, traces, or metrics. Repeat for multiple. [required]")

	flag.Usage = func() {
		fmt.Fprintln(os.Stderr, "e2e-verify polls Coralogix to verify telemetry data arrived from an E2E run.")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "Flags:")
		flag.PrintDefaults()
	}
	flag.Parse()

	// Resolve api-key from env if flag empty.
	// Note: the Coralogix Send-Your-Data key (used by the collector to send data
	// INTO CX) does NOT have query permissions. We need a separate Logs Query Key.
	if *apiKey == "" {
		*apiKey = os.Getenv("E2E_CX_LOGS_QUERY_KEY")
	}

	// Validate required flags
	missing := []string{}
	if *domain == "" {
		missing = append(missing, "--domain")
	}
	if *apiKey == "" {
		missing = append(missing, "--api-key (or E2E_CX_LOGS_QUERY_KEY env var)")
	}
	if *runID == "" {
		missing = append(missing, "--run-id")
	}
	if len(checks) == 0 && *expectations == "" {
		missing = append(missing, "--check (one of: logs, traces, metrics) OR --expectations <file>")
	}
	if len(missing) > 0 {
		fmt.Fprintf(os.Stderr, "ERROR: missing required flags: %s\n\n", strings.Join(missing, ", "))
		flag.Usage()
		os.Exit(2)
	}

	// Determine query start time: --since (explicit RFC3339) wins over --window (relative).
	var sinceTime time.Time
	if *since != "" {
		t, err := time.Parse(time.RFC3339, *since)
		if err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: invalid --since timestamp (want RFC3339): %v\n", err)
			os.Exit(2)
		}
		sinceTime = t
	} else {
		sinceTime = time.Now().Add(-*window)
	}

	// Validate signals
	signals := make([]verify.Signal, 0, len(checks))
	for _, c := range checks {
		switch verify.Signal(c) {
		case verify.SignalLogs, verify.SignalTraces, verify.SignalMetrics:
			signals = append(signals, verify.Signal(c))
		default:
			fmt.Fprintf(os.Stderr, "ERROR: invalid --check %q (want logs|traces|metrics)\n", c)
			os.Exit(2)
		}
	}

	cfg := verify.Config{
		Client:        verify.NewClient(*domain, *apiKey),
		RunID:         *runID,
		Since:         sinceTime,
		Timeout:       *timeout,
		InitialDelay:  *initialDelay,
		LogsFilter:    *logsFilter,
		TracesFilter:  *tracesFilter,
		MetricsFilter: *metricsFilter,
	}

	ctx, cancel := context.WithTimeout(context.Background(), *timeout+30*time.Second)
	defer cancel()

	// --expectations mode: run structured checks from a YAML file.
	if *expectations != "" {
		exp, err := verify.LoadExpectations(*expectations)
		if err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
			os.Exit(2)
		}
		fmt.Fprintf(os.Stderr, "e2e-verify: domain=%s run_id=%s since=%s timeout=%s expectations=%s\n",
			*domain, *runID, sinceTime.Format(time.RFC3339), *timeout, *expectations)

		result := verify.VerifyExpectations(ctx, cfg, exp)

		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(result)

		if !result.Pass {
			fmt.Fprintf(os.Stderr, "FAIL: expectations not met:\n%s", result.FailureSummary())
			os.Exit(1)
		}
		fmt.Fprintln(os.Stderr, "OK: all expectations met")
		return
	}

	// --check mode: existence-only checks (legacy / debugging).
	fmt.Fprintf(os.Stderr, "e2e-verify: domain=%s run_id=%s since=%s timeout=%s checks=%v\n",
		*domain, *runID, sinceTime.Format(time.RFC3339), *timeout, checks)

	results := verify.VerifyAll(ctx, cfg, signals)

	// Print structured JSON summary to stdout
	out := map[string]interface{}{
		"run_id":  *runID,
		"domain":  *domain,
		"since":   sinceTime.Format(time.RFC3339),
		"results": results,
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	if err := enc.Encode(out); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR encoding result: %v\n", err)
		os.Exit(1)
	}

	// Exit non-zero if any check failed
	for _, r := range results {
		if !r.Found {
			fmt.Fprintf(os.Stderr, "FAIL: signal=%s error=%q\n", r.Signal, r.Error)
			os.Exit(1)
		}
	}
	fmt.Fprintln(os.Stderr, "OK: all checks passed")
}
