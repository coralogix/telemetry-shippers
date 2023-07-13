package ecsattributesprocessor

import (
	"context"
	"fmt"
	"regexp"

	"github.com/coralogix/telemetry-shippers/otel-agent/ecs-ec2/ecsattributesprocessor/internal/metadata"
	"go.opentelemetry.io/collector/component"
	"go.opentelemetry.io/collector/pdata/plog"
	"go.opentelemetry.io/collector/processor/processorhelper"
	"go.uber.org/zap"
)

// global variable used to store metadata endpoints within package
var ecsMetadataHandler metadataHandler
var idReg = regexp.MustCompile(`^[a-z0-9]+`)

func processLogsFunc(logger *zap.Logger, c *Config) processorhelper.ProcessLogsFunc {
	return func(ctx context.Context, ld plog.Logs) (plog.Logs, error) {
		for i := 0; i < ld.ResourceLogs().Len(); i++ {
			rlog := ld.ResourceLogs().At(i)
			containerID := getContainerId(&rlog, c.ContainerID.Sources...)
			logger.Debug("processing",
				zap.String("container.id", containerID),
				zap.String("processor", metadata.Type))

			metadata, ok := ecsMetadataHandler.get(containerID)
			if !ok {
				logger.Debug("metadata not found",
					zap.String("container.id", containerID),
					zap.String("processor", metadata.Type))
			}

			// flatten the data
			flattened := metadata.Flat()

			for k, v := range flattened {
				ok, err := c.allowAttr(k)
				if err != nil {
					return ld, err
				}

				if ok {
					rlog.Resource().Attributes().
						PutStr(k, fmt.Sprintf("%v", v))
				}
			}
		}
		return ld, nil
	}
}

func getContainerId(rlog *plog.ResourceLogs, sources ...string) string {
	var id string
	for _, s := range sources {
		if v, ok := rlog.Resource().Attributes().Get(s); ok {
			id = v.AsString()
			break
		}
	}

	// strip any unneeed values for eg. file extension
	id = idReg.FindString(id)
	return id
}

func startFn(logger *zap.Logger) component.StartFunc {
	return func(ctx context.Context, _ component.Host) error {
		ecsMetadataHandler = metadataHandler{
			metadata:  make(map[string]Metadata),
			logger:    logger,
			endpoints: getEndpoints,
			stop:      make(chan struct{}, 1),
		}

		logger.Info("starting")
		return ecsMetadataHandler.start()
	}
}

func shutdownFn() component.ShutdownFunc {
	return func(ctx context.Context) error {
		ecsMetadataHandler.shutdown()
		ecsMetadataHandler.logger.Info("shutdown")
		return nil
	}
}
