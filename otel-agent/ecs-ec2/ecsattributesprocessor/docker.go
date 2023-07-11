package ecsattributesprocessor

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
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
}

func (m *metadataHandler) get(key string) (val Metadata, ok bool) {
	// initial check for metadata
	val, ok = m.metadata[key]
	return
}

func (m *metadataHandler) add(key string, value Metadata) {
	m.metadata[key] = value
}

func (m *metadataHandler) syncMetadata(ctx context.Context, endpoints map[string][]string) (err error) {

	for k, v := range endpoints {
		if _, ok := m.metadata[k]; ok {
			continue // if metadata already exists, skip
		}

		var metadata Metadata
		resp, err := http.Get(v[0]) // use the 1st available endpoint
		if err != nil {
			return fmt.Errorf("failed while calling metadata endpoint for [%s] - %s", k, err)
		}

		if err = json.NewDecoder(resp.Body).Decode(&metadata); err != nil {
			return fmt.Errorf("failed to decode metadata for [%s] - %s", k, err)
		}

		m.add(k, metadata)
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

	return
}

func (m *metadataHandler) start() {
	go func() {
		ctx := context.Background()
		ticker := time.NewTicker(time.Second * 60)

		cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
		if err != nil {
			fmt.Println("Unable to create Docker client", err)
			os.Exit(1)
		}

		dockerEvents, errors := cli.Events(context.Background(), types.EventsOptions{})

		sync := func() {
			endpoints, err := m.endpoints(ctx)
			if err != nil {
				m.logger.Sugar().Errorf("failed to fetch metadata endpoints: %s", err)
				return
			}

			m.Lock()
			m.logger.Debug("updating endpoints", zap.String("processor", metadata.Type))
			if err := m.syncMetadata(ctx, endpoints); err != nil {
				m.logger.Sugar().Errorf("%s failed to update metadata endpoints: %s", metadata.Type, err)
			}

			m.Unlock()
			m.logger.Debug("number of containers with detected metadata endpoints", zap.Int("count", len(endpoints)))
		}

		for {
			select {
			case <-ticker.C:
				sync()

			case event := <-dockerEvents:
				if event.Type == events.ContainerEventType && event.Action == "create" {
					m.logger.Debug("new container id detected, re-syncing metadata", zap.String("id", event.ID))
					sync()
				}

			case err := <-errors:
				m.logger.Sugar().Errorf("error received from docker container events: %s", err)
			}

		}
	}()
}

type endpointsFn func(ctx context.Context) (map[string][]string, error)

func getEndpoints(ctx context.Context) (map[string][]string, error) {
	m := make(map[string][]string)

	// Initialize Docker client
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return m, fmt.Errorf("failed to create Docker client: %s", err)
	}

	// Get the list of running containers
	containers, err := cli.ContainerList(ctx, types.ContainerListOptions{})
	if err != nil {
		return m, fmt.Errorf("failed to fetch Docker containers: %s", err)
	}

	for _, container := range containers {
		// Fetch detailed container information
		containerInfo, err := cli.ContainerInspect(ctx, container.ID)
		if err != nil {
			return m, fmt.Errorf("failed to inspect Docker container %s: %s", container.ID, err)
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

func getEndpointsByID(containerID string) (map[string][]string, error) {
	// Initialize Docker client
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return nil, fmt.Errorf("failed to create docker client: %s", err)
	}

	c, err := cli.ContainerInspect(context.Background(), containerID)
	if err != nil {
		return nil, fmt.Errorf("failed to inspect docker container %s: %s", containerID, err)
	}

	var endpoints []string

	for _, env := range c.Config.Env {

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

	m := make(map[string][]string)
	m[containerID] = endpoints
	return m, nil
}
