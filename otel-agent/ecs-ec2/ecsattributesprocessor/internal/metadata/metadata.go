package metadata

import (
	"go.opentelemetry.io/collector/component"
)

const (
	Type = "ecsattributes"
	// TracesStability  = component.StabilityLevelBeta
	// MetricsStability = component.StabilityLevelBeta
	LogsStability = component.StabilityLevelBeta
)
