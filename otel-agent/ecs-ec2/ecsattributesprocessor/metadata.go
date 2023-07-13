package ecsattributesprocessor

import (
	"fmt"
	"time"
)

type Metadata struct {
	ContainerARN  string    `json:"ContainerARN"`
	CreatedAt     time.Time `json:"CreatedAt"`
	DesiredStatus string    `json:"DesiredStatus"`
	DockerID      string    `json:"DockerId"`
	DockerName    string    `json:"DockerName"`
	Image         string    `json:"Image"`
	ImageID       string    `json:"ImageID"`
	KnownStatus   string    `json:"KnownStatus"`
	Labels        Labels    `json:"Labels"`
	Limits        struct {
		CPU    int `json:"CPU"`
		Memory int `json:"Memory"`
	} `json:"Limits"`
	Name      string    `json:"Name"`
	Networks  []Network `json:"Networks"`
	Ports     []Port    `json:"Ports"`
	StartedAt time.Time `json:"StartedAt"`
	Type      string    `json:"Type"`
	Volumes   []Volume  `json:"Volumes"`
}

type Labels struct {
	ComAmazonawsEcsCluster               string `json:"com.amazonaws.ecs.cluster"`
	ComAmazonawsEcsContainerName         string `json:"com.amazonaws.ecs.container-name"`
	ComAmazonawsEcsTaskArn               string `json:"com.amazonaws.ecs.task-arn"`
	ComAmazonawsEcsTaskDefinitionFamily  string `json:"com.amazonaws.ecs.task-definition-family"`
	ComAmazonawsEcsTaskDefinitionVersion string `json:"com.amazonaws.ecs.task-definition-version"`
}

type Network struct {
	IPv4Addresses []string `json:"IPv4Addresses"`
	NetworkMode   string   `json:"NetworkMode"`
}

type Port struct {
	ContainerPort int    `json:"ContainerPort"`
	HostIP        string `json:"HostIp"`
	HostPort      int    `json:"HostPort"`
	Protocol      string `json:"Protocol"`
}

type Volume struct {
	Destination string `json:"Destination"`
	Source      string `json:"Source"`
}

func (m *Metadata) Flat() map[string]any {
	flattened := make(map[string]any)

	flattened["aws.ecs.container.arn"] = m.ContainerARN
	flattened["aws.ecs.task.known.status"] = m.KnownStatus
	flattened["aws.ecs.cluster"] = m.Labels.ComAmazonawsEcsCluster
	flattened["aws.ecs.container.name"] = m.Labels.ComAmazonawsEcsContainerName
	flattened["aws.ecs.task.arn"] = m.Labels.ComAmazonawsEcsTaskArn
	flattened["aws.ecs.task.definition.family"] = m.Labels.ComAmazonawsEcsTaskDefinitionFamily
	flattened["aws.ecs.task.definition.version"] = m.Labels.ComAmazonawsEcsTaskDefinitionVersion
	flattened["created.at"] = m.CreatedAt.Format(time.RFC3339Nano)
	flattened["desired.status"] = m.DesiredStatus
	flattened["docker.id"] = m.DockerID
	flattened["docker.name"] = m.DockerName
	flattened["image"] = m.Image
	flattened["image.id"] = m.ImageID
	flattened["limits.cpu"] = m.Limits.CPU
	flattened["limits.memory"] = m.Limits.Memory
	flattened["name"] = m.Name
	flattened["started.at"] = m.StartedAt.Format(time.RFC3339Nano)
	flattened["type"] = m.Type

	// add networks
	for i, network := range m.Networks {
		flattened[fmt.Sprintf("networks.%d.network.mode", i)] = network.NetworkMode
		for ind, ipv4 := range network.IPv4Addresses {
			flattened[fmt.Sprintf("networks.%d.ipv4.addresses.%d", i, ind)] = ipv4
		}
	}

	// add ports
	for i, port := range m.Ports {
		flattened[fmt.Sprintf("ports.%d.container.port", i)] = port.ContainerPort
		flattened[fmt.Sprintf("ports.%d.host.ip", i)] = port.HostIP
		flattened[fmt.Sprintf("ports.%d.host.port", i)] = port.HostPort
		flattened[fmt.Sprintf("ports.%d.protocol", i)] = port.Protocol
	}

	// add volumes
	for i, volume := range m.Volumes {
		flattened[fmt.Sprintf("volumes.%d.destination", i)] = volume.Destination
		flattened[fmt.Sprintf("volumes.%d.source", i)] = volume.Source
	}

	return flattened
}
