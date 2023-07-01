package ecslogresourcedetectionprocessor

import (
	"context"
	"fmt"

	"github.com/coralogix/telemetry-shippers/otel-agent/ecs-ec2/ecslogresourcedetectionprocessor/internal/metadata"
	"go.opentelemetry.io/collector/component"
	"go.opentelemetry.io/collector/consumer"
	"go.opentelemetry.io/collector/processor"
	"go.opentelemetry.io/collector/processor/processorhelper"
)

// Factory, builds a new instance of the component

const (
	// The value of "type" key in configuration.
	typeStr = "ecslogresourcedetectionprocessor"
)

var (
	consumerCapabilities = consumer.Capabilities{MutatesData: true}
	componentStability   = component.StabilityLevelAlpha
)

type factory struct{}

// NewFactory creates a factory for the routing processor.
func NewFactory() processor.Factory {
	// fmt.Println("NewFactory for ecslogresourcedetectionprocessor")
	f := &factory{}

	return processor.NewFactory(
		metadata.Type,
		createDefaultConfig,
		processor.WithLogs(f.createLogsProcessor, componentStability),
	)
}

func createDefaultConfig() component.Config {
	return &Config{
		// HTTPClientSettings: confighttp.HTTPClientSettings{},
		Attributes: []string{
			// by default, we collect all tribute nameaå that start with:
			// ecs, name, image or docker
			"^ecs.*|^image.*|^docker.*",
		},
	}
}

func (f *factory) createLogsProcessor(
	ctx context.Context,
	set processor.CreateSettings,
	cfg component.Config,
	nextConsumer consumer.Logs,
) (processor.Logs, error) {

	// create logger
	logger := set.TelemetrySettings.Logger

	// do something with comfig here
	// TODO: add config validation
	config, ok := cfg.(*Config)
	if !ok {
		return nil, fmt.Errorf("invalid config for processor %s", typeStr)
	}

	return processorhelper.NewLogsProcessor(
		ctx,
		set,
		cfg,
		nextConsumer,
		processLogsFunc(logger, config),
		processorhelper.WithCapabilities(consumerCapabilities),
		processorhelper.WithStart(startFn(logger)),
	)
}
