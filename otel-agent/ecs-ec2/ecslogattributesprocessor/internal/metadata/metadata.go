package metadata

import (
	"go.opentelemetry.io/collector/component"
)

const (
	Type = "ecslogattributes"
	// TracesStability  = component.StabilityLevelBeta
	// MetricsStability = component.StabilityLevelBeta
	LogsStability = component.StabilityLevelBeta
)
