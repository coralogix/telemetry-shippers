package ecsattributesprocessor

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"sync"
	"time"

	"github.com/coralogix/telemetry-shippers/otel-agent/ecs-ec2/ecsattributesprocessor/internal/metadata"
	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/events"
	"github.com/docker/docker/client"
	"go.uber.org/zap"
)

const (
	ecsContainerMetadataURIv4 = "ECS_CONTAINER_METADATA_URI_V4"
	ecsContainerMetadataURI   = "ECS_CONTAINER_METADATA_URI"
)

type metadataHandler struct {
	sync.Mutex
	// endpoints map[string][]string
	metadata map[string]Metadata

	// logger
	logger *zap.Logger

	// endpoints -  function used to fetch metadata endpoints
	endpoints endpointsFn

	stop chan struct{}
}

func (m *metadataHandler) get(key string) (Metadata, bool) {
	// initial check for metadata
	val, ok := m.metadata[key]
	return val, ok
}

func (m *metadataHandler) syncMetadata(ctx context.Context, endpoints map[string][]string) error {

	for k, v := range endpoints {
		if _, ok := m.metadata[k]; ok {
			continue // if metadata already exists, skip
		}

		var metadata Metadata
		resp, err := http.Get(v[0]) // use the 1st available endpoint
		if err != nil {
			return fmt.Errorf("failed while calling metadata endpoint for [%s] - %w", k, err)
		}

		if err = json.NewDecoder(resp.Body).Decode(&metadata); err != nil {
			return fmt.Errorf("failed to decode metadata for [%s] - %w", k, err)
		}

		m.metadata[k] = metadata
	}

	// remove keys that don't exist in current endpoint view
	// Note: this insures that the amount of metadata we store stays
	// in line with the number of containers discovered and prevents
	// us accumulating unused metadata indifinitely
	for k := range m.metadata {
		if _, ok := endpoints[k]; !ok {
			delete(m.metadata, k)
		}
	}

	return nil
}

func (m *metadataHandler) start() error {
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		m.logger.Sugar().Errorf("failed to intial docker API client: %w", err)
		return err
	}

	// initial sync
	if err := syncMetadata(context.Background(), m); err != nil {
		m.logger.Sugar().Errorf("failed to sync metadata: %w", err)
		return err
	}

	go func() {
		ctx := context.Background()
		ticker := time.NewTicker(time.Second * 60)

		dockerEvents, errors := cli.Events(context.Background(), types.EventsOptions{})

		for {
			select {
			case <-ticker.C:
				if err := syncMetadata(ctx, m); err != nil {
					m.logger.Sugar().Errorf("failed to sync metadata: %w", err)
				}

			case event := <-dockerEvents:
				if !(event.Type == events.ContainerEventType && event.Action == "create") {
					continue
				}

				m.logger.Debug("new container id detected, re-syncing metadata", zap.String("id", event.ID))
				if err := syncMetadata(ctx, m); err != nil {
					m.logger.Sugar().Errorf("failed to sync metadata: %w", err)
				}

			case err := <-errors:
				m.logger.Sugar().Errorf("error received from docker container events: %w", err)

			case <-m.stop:
				m.logger.Debug("stopping metadata sync")
				return
			}
		}
	}()

	return err
}

func (m *metadataHandler) shutdown() error {
	m.stop <- struct{}{}
	close(m.stop)
	return nil
}

type endpointsFn func(ctx context.Context) (map[string][]string, error)

func getEndpoints(ctx context.Context) (map[string][]string, error) {
	m := make(map[string][]string)

	// Initialize Docker client
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return m, fmt.Errorf("failed to create Docker client: %w", err)
	}

	// Get the list of running containers
	containers, err := cli.ContainerList(ctx, types.ContainerListOptions{})
	if err != nil {
		return m, fmt.Errorf("failed to fetch Docker containers: %w", err)
	}

	for _, container := range containers {
		// Fetch detailed container information
		containerInfo, err := cli.ContainerInspect(ctx, container.ID)
		if err != nil {
			return m, fmt.Errorf("failed to inspect Docker container %s: %w", container.ID, err)
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
			m[container.ID] = endpoints
		}
	}

	return m, nil
}

func syncMetadata(ctx context.Context, m *metadataHandler) error {
	endpoints, err := m.endpoints(ctx)
	if err != nil {
		return fmt.Errorf("failed to fetch metadata endpoints: %w", err)
	}

	m.Lock()
	m.logger.Debug("updating endpoints", zap.String("processor", metadata.Type))
	if err := m.syncMetadata(ctx, endpoints); err != nil {
		return fmt.Errorf("%s failed to update metadata endpoints: %w", metadata.Type, err)
	}

	m.Unlock()
	m.logger.Debug("number of containers with detected metadata endpoints", zap.Int("count", len(endpoints)))
	return nil
}
