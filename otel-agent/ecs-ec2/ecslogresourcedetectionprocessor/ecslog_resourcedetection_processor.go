package ecslogresourcedetectionprocessor

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strings"

	"github.com/coralogix/telemetry-shippers/otel-agent/ecs-ec2/ecslogresourcedetectionprocessor/internal/metadata"
	"github.com/coralogix/telemetry-shippers/otel-agent/ecs-ec2/ecslogresourcedetectionprocessor/internal/utils"
	"go.opentelemetry.io/collector/component"
	"go.opentelemetry.io/collector/pdata/plog"
	"go.opentelemetry.io/collector/processor/processorhelper"
	"go.uber.org/zap"
)

// global variable used to store metadata endpoints within package
var ecsMetadataHandler metadataHandler

func processLogsFunc(logger *zap.Logger, c *Config) processorhelper.ProcessLogsFunc {
	return func(ctx context.Context, ld plog.Logs) (plog.Logs, error) {
		for i := 0; i < ld.ResourceLogs().Len(); i++ {
			rlog := ld.ResourceLogs().At(i)
			containerID := getContainerId(&rlog)
			logger.Debug("processing",
				zap.String("container.id", containerID),
				zap.String("processor", metadata.Type))

			// check for ecs agent, Note that ecs agents do not have
			// metadata endpoints
			if ok, _ := isECSAgent(containerID); ok {
				rlog.Resource().Attributes().PutStr("ecs.agent", "true")
			}

			endpoints, ok := ecsMetadataHandler.get(containerID)
			if !ok || len(endpoints) == 0 {
				logger.Debug("metadata not found",
					zap.String("container.id", containerID),
					zap.String("processor", metadata.Type))
				return ld, nil
			}

			resp, err := http.Get(endpoints[0])
			if err != nil {
				return ld, err
			}

			var data map[string]interface{}
			if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
				return ld, err
			}

			// flatten the data
			flattened := make(map[string]interface{})
			utils.Flatten(data, "", flattened)

			for k, v := range flattened {
				formattedKey := formatLabel(k)
				ok, err := c.allowAttr(formattedKey)
				if err != nil {
					return ld, err
				}

				if ok {
					rlog.Resource().Attributes().
						PutStr(formattedKey, fmt.Sprintf("%v", v))
				}
			}
		}
		return ld, nil
	}
}

func formatLabel(k string) (formatedKey string) {
	formatedKey = k
	reg := regexp.MustCompile(`Labels.com.amazonaws.|Labels.`)
	if reg.MatchString(k) {
		formatedKey = reg.ReplaceAllString(k, "")
	}

	reg = regexp.MustCompile(`(^[A-Z].*[a-z])([A-Z]{2,})`)
	if reg.MatchString(k) {
		formatedKey = reg.ReplaceAllString(k, "${1}.${2}")
	}

	reg = regexp.MustCompile(`(^[A-Z].*[a-z0-9])([A-Z]{1,}[a-z].*)`)
	if reg.MatchString(k) {
		formatedKey = reg.ReplaceAllString(k, "${1}.${2}")
	}

	// convert to lower case and replace all - with .
	formatedKey = strings.ReplaceAll(formatedKey, "-", ".")
	formatedKey = strings.ToLower(formatedKey)
	return
}

func getContainerId(rlog *plog.ResourceLogs) (id string) {
	if v, ok := rlog.Resource().Attributes().Get("log.file.name"); ok {
		id = regexp.MustCompile(`^[a-z0-9]+`).
			FindString(v.AsString())
	}

	if v, ok := rlog.Resource().Attributes().Get("container.id"); ok {
		id = v.AsString()
	}
	return
}

func startFn(logger *zap.Logger) func(ctx context.Context, host component.Host) error {
	return func(ctx context.Context, host component.Host) error {
		ecsMetadataHandler = metadataHandler{
			endpoints: make(map[string][]string),
		}

		ecsMetadataHandler.start(logger)
		logger.Info("started")
		return nil
	}
}
