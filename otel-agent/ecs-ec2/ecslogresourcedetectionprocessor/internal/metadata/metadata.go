package metadata

import (
	"go.opentelemetry.io/collector/component"
)

const (
	Type = "ecslogresourcedetection"
	// TracesStability  = component.StabilityLevelBeta
	// MetricsStability = component.StabilityLevelBeta
	LogsStability = component.StabilityLevelBeta
)
