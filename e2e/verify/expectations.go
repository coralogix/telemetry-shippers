package verify

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

// Expectations describes what a test run should find in Coralogix to count
// as a pass. It is loaded from a per-target YAML file and used by
// VerifyExpectations.
//
// Each section is optional. A nil section means "do not check this signal".
// Within a section, an empty list of required attributes/labels means
// "only check min_count, no per-record assertions".
type Expectations struct {
	Logs            *SignalExpectation    `yaml:"logs,omitempty"`
	Traces          *SignalExpectation    `yaml:"traces,omitempty"`
	Metrics         *SignalExpectation    `yaml:"metrics,omitempty"`
	CollectorHealth *CollectorHealthCheck `yaml:"collector_health,omitempty"`
}

// SignalExpectation describes the assertions for a single signal
// (logs, traces, or metrics).
type SignalExpectation struct {
	// MinCount is the minimum number of records that must arrive in CX.
	// Zero is treated as 1 (we always require at least one record per signal
	// when the section is defined).
	MinCount int `yaml:"min_count"`

	// RequiredAttributes are OTel resource attribute keys (with dots, as
	// they appear in OTel) that every returned record must carry. Used for
	// logs and traces (DataPrime path: $d.resource.attributes.<key>).
	RequiredAttributes []string `yaml:"required_attributes,omitempty"`

	// RequiredLabels are PromQL label names (already dot-converted to
	// underscores by the Coralogix exporter) that every returned metric
	// series must carry. Used for metrics only.
	RequiredLabels []string `yaml:"required_labels,omitempty"`
}

// CollectorHealthCheck describes constraints on the collector's own
// self-monitoring metrics (otelcol_*). These reveal pipeline issues that
// don't show up as missing data — e.g., the Coralogix exporter rejecting
// records due to label-length limits.
type CollectorHealthCheck struct {
	// MaxSendFailures is the maximum allowed value of
	// sum(otelcol_exporter_send_failed_records_total) across all exporters
	// for this run_id. Zero means no failures tolerated.
	MaxSendFailures int `yaml:"max_send_failures"`
}

// LoadExpectations reads a YAML file and returns the parsed Expectations.
func LoadExpectations(path string) (*Expectations, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read expectations file %s: %w", path, err)
	}

	var exp Expectations
	if err := yaml.Unmarshal(data, &exp); err != nil {
		return nil, fmt.Errorf("parse expectations file %s: %w", path, err)
	}

	// Normalize: a defined section with min_count=0 means "at least 1".
	for _, s := range []*SignalExpectation{exp.Logs, exp.Traces, exp.Metrics} {
		if s != nil && s.MinCount < 1 {
			s.MinCount = 1
		}
	}

	return &exp, nil
}
