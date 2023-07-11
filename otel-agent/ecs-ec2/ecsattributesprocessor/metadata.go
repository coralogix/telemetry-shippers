package ecslogattributesprocessor

import (
	"fmt"
	"reflect"
	"strings"
	"time"
)

type Metadata struct {
	ContainerARN  string    `json:"ContainerARN" flat:"container.arn"`
	CreatedAt     time.Time `json:"CreatedAt" flat:"created.at"`
	DesiredStatus string    `json:"DesiredStatus" flat:"desired.status"`
	DockerID      string    `json:"DockerId" flat:"docker.id"`
	DockerName    string    `json:"DockerName" flat:"docker.name"`
	Image         string    `json:"Image" flat:"image"`
	ImageID       string    `json:"ImageID" flat:"image.id"`
	KnownStatus   string    `json:"KnownStatus" flat:"known.status"`
	Labels        Labels    `json:"Labels" flat:""`
	Limits        struct {
		CPU    int `json:"CPU" flat:"cpu"`
		Memory int `json:"Memory" flat:"memory"`
	} `json:"Limits" flat:"limits"`
	Name      string    `json:"Name" flat:"name"`
	Networks  []Network `json:"Networks" flat:"networks"`
	Ports     []Port    `json:"Ports" flat:"ports"`
	StartedAt time.Time `json:"StartedAt" flat:"started.at"`
	Type      string    `json:"Type" flat:"type"`
	Volumes   []Volume  `json:"Volumes" flat:"volumes"`
}

type Labels struct {
	ComAmazonawsEcsCluster               string `json:"com.amazonaws.ecs.cluster" flat:"ecs.cluster"`
	ComAmazonawsEcsContainerName         string `json:"com.amazonaws.ecs.container-name" flat:"ecs.container.name"`
	ComAmazonawsEcsTaskArn               string `json:"com.amazonaws.ecs.task-arn" flat:"ecs.task.arn"`
	ComAmazonawsEcsTaskDefinitionFamily  string `json:"com.amazonaws.ecs.task-definition-family" flat:"ecs.task.definition.family"`
	ComAmazonawsEcsTaskDefinitionVersion string `json:"com.amazonaws.ecs.task-definition-version" flat:"ecs.task.definition.version"`
}

type Network struct {
	IPv4Addresses []string `json:"IPv4Addresses" flat:"ipv4.addresses"`
	NetworkMode   string   `json:"NetworkMode" flat:"network.mode"`
}

type Port struct {
	ContainerPort int    `json:"ContainerPort" flat:"container.port"`
	HostIP        string `json:"HostIp" flat:"host.ip"`
	HostPort      int    `json:"HostPort" flat:"host.port"`
	Protocol      string `json:"Protocol" flat:"protocol"`
}

type Volume struct {
	Destination string `json:"Destination" flat:"destination"`
	Source      string `json:"Source" flat:"source"`
}

// Flat - returns flat map representation of the metadata structure, using the "flat" tag
func (m *Metadata) Flat() map[string]interface{} {
	result := make(map[string]interface{})
	flattenType("", reflect.ValueOf(*m), result)
	return result
}

func flattenType(prefix string, val reflect.Value, result map[string]interface{}) {
	prefix = strings.TrimLeft(prefix, ".") // trim leading dot
	valType := val.Type()

	for i := 0; i < val.NumField(); i++ {
		fieldType := valType.Field(i)
		fieldValue := val.Field(i)

		if fieldValue.Kind() == reflect.Ptr {
			fieldValue = fieldValue.Elem()
			if !fieldValue.IsValid() {
				continue
			}
		}
		flatTag, hasTag := fieldType.Tag.Lookup("flat")

		switch fieldValue.Kind() {
		case reflect.Struct:
			flattenType(
				prefix+flatTag+".",
				fieldValue, result)

		case reflect.Slice:
			for j := 0; j < fieldValue.Len(); j++ {
				sliceVal := fieldValue.Index(j)

				if sliceVal.Kind() == reflect.String {
					if hasTag {
						result[fmt.Sprintf("%s%s.%d", prefix, flatTag, j)] = sliceVal.Interface()
						continue
					}
				}

				flattenType(fmt.Sprintf("%s%s.%d.", prefix, flatTag, j), sliceVal, result)
			}
		default:
			if hasTag {
				result[fmt.Sprintf("%s%s", prefix, flatTag)] = fieldValue.Interface()
				continue
			}
		}
	}
}
