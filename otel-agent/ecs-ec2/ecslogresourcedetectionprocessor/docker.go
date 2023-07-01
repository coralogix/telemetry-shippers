package ecslogresourcedetectionprocessor

import (
	"context"
	"fmt"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/coralogix/telemetry-shippers/otel-agent/ecs-ec2/ecslogresourcedetectionprocessor/internal/metadata"
	"github.com/docker/docker/api/types"
	"github.com/docker/docker/client"
	"go.uber.org/zap"
)

const (
	ecsContainerMetadataURIv4 = "ECS_CONTAINER_METADATA_URI_V4"
	ecsContainerMetadataURI   = "ECS_CONTAINER_METADATA_URI"
)

type metadataHandler struct {
	sync.Mutex
	endpoints  map[string][]string
	socketPath string
}

func (m *metadataHandler) get(key string) ([]string, bool) {
	val, ok := m.endpoints[key]
	return val, ok
}

func (m *metadataHandler) add(key string, value []string) {
	m.endpoints[key] = value
}

func (m *metadataHandler) getEndpoints(ctx context.Context) error {

	// Initialize Docker client
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return fmt.Errorf("failed to create Docker client: %s\n", err)
	}

	// Get the list of running containers
	containers, err := cli.ContainerList(ctx, types.ContainerListOptions{})
	if err != nil {
		return fmt.Errorf("failed to fetch Docker containers: %s\n", err)
	}

	for _, container := range containers {
		// Fetch detailed container information
		containerInfo, err := cli.ContainerInspect(ctx, container.ID)
		if err != nil {
			return fmt.Errorf("failed to inspect Docker container %s: %s\n", container.ID, err)
		}
		var endpoints []string
		for _, env := range containerInfo.Config.Env {

			// use regex to match ECS_CONTAINER_METADATA_URI_V4 and ECS_CONTAINER_METADATA_URI
			for _, n := range []string{ecsContainerMetadataURIv4, ecsContainerMetadataURI} {
				reg := regexp.MustCompile(fmt.Sprintf(`^%s=(.*$)`, n))
				if !reg.MatchString(env) {
					continue
				}

				matches := reg.FindStringSubmatch(env)
				if len(matches) < 2 {
					continue
				}

				endpoints = append(endpoints, matches[1])
			}
		}

		// only record if there are endpoints
		if len(endpoints) > 0 {
			m.add(container.ID, endpoints)
		}

	}

	return nil
}

func (m *metadataHandler) start(logger *zap.Logger) {
	go func() {
		ticker := time.NewTicker(time.Second * 60)
		for ; true; <-ticker.C {
			m.Lock()
			logger.Debug("updating endpoints", zap.String("processor", metadata.Type))
			if err := m.getEndpoints(context.Background()); err != nil {
				logger.Sugar().Errorf("%s failed to update metadata endpoints: %s", metadata.Type, err)
			}
			m.Unlock()
			logger.Debug("number of containers with detected metadata endpoints", zap.Int("count", len(m.endpoints)))
		}
	}()
}

func (m *metadataHandler) shutdown() {}

func isECSAgent(containerID string) (isAgent bool, err error) {
	// Initialize Docker client
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return isAgent, fmt.Errorf("failed to create docker client: %s\n", err)
	}

	c, err := cli.ContainerInspect(context.Background(), containerID)
	if err != nil {
		return isAgent, fmt.Errorf("failed to inspect docker container %s: %s\n", containerID, err)
	}

	if strings.Contains(c.Config.Image, "amazon/amazon-ecs-agent") {
		isAgent = true
	}

	return
}
