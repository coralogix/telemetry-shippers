package ecsattributesprocessor

import (
	"context"
	"fmt"

	"github.com/coralogix/telemetry-shippers/otel-agent/ecs-ec2/ecsattributesprocessor/internal/metadata"
	"go.opentelemetry.io/collector/component"
	"go.opentelemetry.io/collector/consumer"
	"go.opentelemetry.io/collector/processor"
	"go.opentelemetry.io/collector/processor/processorhelper"
)

// Factory, builds a new instance of the component

const (
	// The value of "type" key in configuration.
	typeStr = "ecsattributesprocessor"
)

var (
	consumerCapabilities = consumer.Capabilities{MutatesData: true}
	componentStability   = component.StabilityLevelAlpha
)

type factory struct{}

// NewFactory creates a factory for the routing processor.
func NewFactory() processor.Factory {
	f := &factory{}

	return processor.NewFactory(
		metadata.Type,
		createDefaultConfig,
		processor.WithLogs(f.createLogsProcessor, componentStability),
	)
}

func createDefaultConfig() component.Config {
	return &Config{
		Attributes: []string{
			// by default, we collect all tribute nameaå that start with:
			// ecs, name, image or docker
			"^aws.ecs.*|^image.*|^docker.*|^labels.*",
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

	// TODO: add config validation
	config, ok := cfg.(*Config)
	if !ok {
		return nil, fmt.Errorf("invalid config for processor %s", typeStr)
	}

	// initialise config
	if err := config.init(); err != nil {
		return nil, err
	}

	return processorhelper.NewLogsProcessor(
		ctx,
		set,
		cfg,
		nextConsumer,
		processLogsFunc(logger, config),
		processorhelper.WithCapabilities(consumerCapabilities),
		processorhelper.WithStart(startFn(logger)),
		processorhelper.WithShutdown(shutdownFn()),
	)
}
