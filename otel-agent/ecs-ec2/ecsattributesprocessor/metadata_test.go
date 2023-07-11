package ecslogattributesprocessor

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/require"
	"gotest.tools/v3/assert"
)

func TestMetadataFlatten(t *testing.T) {
	var metadata Metadata
	require.NoError(t, json.Unmarshal([]byte(payload), &metadata))
	expected := map[string]interface{}{
		"container.arn":               "arn:aws:ecs:eu-west-1:035955823196:container/cds-305/ec7ff82b7a3a44a5bbbe9bcf11daee33/cc1c133f-bd1f-4006-8dae-4cd8a3f54f19",
		"desired.status":              "RUNNING",
		"docker.id":                   "196a0e6abfce1e31ee24b65e97875f089878dd7d1d7e9f15155d6094c8b908f5",
		"docker.name":                 "ecs-cadvisor-task-definition-7-cadvisor-bae592b5e4c1a3bb3800",
		"ecs.cluster":                 "cds-305",
		"ecs.container.name":          "cadvisor",
		"ecs.task.arn":                "arn:aws:ecs:eu-west-1:035955823196:task/cds-305/ec7ff82b7a3a44a5bbbe9bcf11daee33",
		"ecs.task.definition.family":  "cadvisor-task-definition",
		"ecs.task.definition.version": "7",
		"image":                       "gcr.io/cadvisor/cadvisor:latest",
		"image.id":                    "sha256:68c29634fe49724f94ed34f18224316f776392f7a5a4014969ac5798a2ec96dc",
		"known.status":                "RUNNING",
		"limits.cpu":                  10,
		"limits.memory":               300,
		"name":                        "cadvisor",
		"networks.0.ipv4.addresses.0": "172.17.0.2",
		"networks.0.network.mode":     "bridge",
		"ports.0.container.port":      8080,
		"ports.0.host.ip":             "0.0.0.0",
		"ports.0.host.port":           32911,
		"ports.0.protocol":            "tcp",
		"ports.1.container.port":      8080,
		"ports.1.host.ip":             "::",
		"ports.1.host.port":           32911,
		"ports.1.protocol":            "tcp",
		"type":                        "NORMAL",
		"volumes.0.destination":       "/var",
		"volumes.0.source":            "/var",
		"volumes.1.destination":       "/etc",
		"volumes.1.source":            "/etc",
	}
	assert.DeepEqual(t, expected, metadata.Flat())
}
