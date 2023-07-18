package ecsattributesprocessor

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"regexp"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/pdata/pcommon"
	"go.opentelemetry.io/collector/pdata/plog"
	"go.uber.org/zap"
)

const payload = `{
	"ContainerARN": "arn:aws:ecs:eu-west-1:035955823396:container/cds-305/ec7ff82b7a3a44a5bbbe9bcf11daee33/cc1c133f-bd1f-4006-8dae-4cd8a3f54f19",
	"CreatedAt": "2023-06-22T12:41:18.335883278Z",
	"DesiredStatus": "RUNNING",
	"DockerId": "196a0e6abfce1e33ee24b65e97875f089878dd7d1d7e9f15155d6094c8b908f5",
	"DockerName": "ecs-cadvisor-task-definition-7-cadvisor-bae592b5e4c1a3bb3800",
	"Image": "gcr.io/cadvisor/cadvisor:latest",
	"ImageID": "sha256:68c29634fe49724f94ed34f18224336f776392f7a5a4014969ac5798a2ec96dc",
	"KnownStatus": "RUNNING",
	"Labels": {
	  "com.custom.app": "go-test-app",
	  "com.amazonaws.ecs.cluster": "cds-305",
	  "com.amazonaws.ecs.container-name": "cadvisor",
	  "com.amazonaws.ecs.task-arn": "arn:aws:ecs:eu-west-1:035955823396:task/cds-305/ec7ff82b7a3a44a5bbbe9bcf11daee33",
	  "com.amazonaws.ecs.task-definition-family": "cadvisor-task-definition",
	  "com.amazonaws.ecs.task-definition-version": "7"
	},
	"Limits": {
	  "CPU": 10,
	  "Memory": 300
	},
	"Name": "cadvisor",
	"Networks": [
	  {
		"IPv4Addresses": [
		  "172.17.0.2"
		],
		"NetworkMode": "bridge"
	  }
	],
	"Ports": [
	  {
		"ContainerPort": 8080,
		"HostIp": "0.0.0.0",
		"HostPort": 32911,
		"Protocol": "tcp"
	  },
	  {
		"ContainerPort": 8080,
		"HostIp": "::",
		"HostPort": 32911,
		"Protocol": "tcp"
	  }
	],
	"StartedAt": "2023-06-22T12:41:18.713571182Z",
	"Type": "NORMAL",
	"Volumes": [
	  {
		"Destination": "/var",
		"Source": "/var"
	  },
	  {
		"Destination": "/etc",
		"Source": "/etc"
	  }
	]
  }
`

var (
	testcontainerID           = "0123456789"
	testendpoints             = make(map[string][]string)
	expectedFlattenedMetadata = map[string]interface{}{
		"aws.ecs.cluster":                 "cds-305",
		"aws.ecs.container.arn":           "arn:aws:ecs:eu-west-1:035955823396:container/cds-305/ec7ff82b7a3a44a5bbbe9bcf11daee33/cc1c133f-bd1f-4006-8dae-4cd8a3f54f19",
		"aws.ecs.container.name":          "cadvisor",
		"aws.ecs.task.arn":                "arn:aws:ecs:eu-west-1:035955823396:task/cds-305/ec7ff82b7a3a44a5bbbe9bcf11daee33",
		"aws.ecs.task.definition.family":  "cadvisor-task-definition",
		"aws.ecs.task.definition.version": "7",
		"aws.ecs.task.known.status":       "RUNNING",
		"created.at":                      "2023-06-22T12:41:18.335883278Z",
		"desired.status":                  "RUNNING",
		"docker.id":                       "196a0e6abfce1e33ee24b65e97875f089878dd7d1d7e9f15155d6094c8b908f5",
		"docker.name":                     "ecs-cadvisor-task-definition-7-cadvisor-bae592b5e4c1a3bb3800",
		"image":                           "gcr.io/cadvisor/cadvisor:latest",
		"image.id":                        "sha256:68c29634fe49724f94ed34f18224336f776392f7a5a4014969ac5798a2ec96dc",
		"limits.cpu":                      10,
		"limits.memory":                   300,
		"name":                            "cadvisor",
		"networks.0.ipv4.addresses.0":     "172.17.0.2",
		"networks.0.network.mode":         "bridge",
		"ports.0.container.port":          8080,
		"ports.0.host.ip":                 "0.0.0.0",
		"ports.0.host.port":               32911,
		"ports.0.protocol":                "tcp",
		"ports.1.container.port":          8080,
		"ports.1.host.ip":                 "::",
		"ports.1.host.port":               32911,
		"ports.1.protocol":                "tcp",
		"started.at":                      "2023-06-22T12:41:18.713571182Z",
		"type":                            "NORMAL",
		"volumes.0.destination":           "/var",
		"volumes.0.source":                "/var",
		"volumes.1.destination":           "/etc",
		"volumes.1.source":                "/etc",
		"labels.com.custom.app":           "go-test-app",
	}
)

func mockMetadataEndpoint(w http.ResponseWriter, r *http.Request) {
	var m map[string]any
	json.Unmarshal([]byte(payload), &m)
	sc := http.StatusOK
	w.WriteHeader(sc)
	json.NewEncoder(w).Encode(m)
}

func TestMain(m *testing.M) {
	// setup()
	server := httptest.NewServer(http.HandlerFunc(mockMetadataEndpoint))
	ecsMetadataHandler = metadataHandler{
		metadata: make(map[string]Metadata),
		logger:   zap.NewExample(),
		endpoints: func(ctx context.Context) (map[string][]string, error) {
			return map[string][]string{
				testcontainerID: {server.URL},
			}, nil
		},
	}

	testendpoints[testcontainerID] = []string{server.URL}

	code := m.Run()
	server.Close()
	os.Exit(code)
}

func TestMetadataHandlerGet(t *testing.T) {
	ctx := context.Background()
	require.NoError(t, ecsMetadataHandler.syncMetadata(ctx, testendpoints))

	v, ok := ecsMetadataHandler.get(testcontainerID)
	flat := v.Flat()
	for k, val := range expectedFlattenedMetadata {
		assert.Equal(t, flat[k], val, "bad key: %s", k)
	}
	assert.True(t, ok)
	assert.Equal(t, len(expectedFlattenedMetadata), len(v.Flat()))
}

func TestProcessLogFunc(t *testing.T) {
	defaultRecord := func() plog.Logs {
		ld := plog.NewLogs()
		ld.ResourceLogs().AppendEmpty().Resource().Attributes().PutStr("container.id", testcontainerID)
		return ld
	}

	tests := []struct {
		name    string
		config  *Config
		wantErr bool
		len     int
		match   string
		record  func() plog.Logs
	}{
		{
			name: "fetch all attributes starting with ecs",
			len:  7,
			config: &Config{
				Attributes: []string{
					"^aws.*",
				},
				ContainerID: ContainerID{
					Sources: []string{"container.id"},
				},
			},
			wantErr: false,
			match:   "^aws.*",
			record:  defaultRecord,
		},
		{
			name: "fetch all attributes",
			len:  34,
			config: &Config{
				Attributes: []string{
					".*",
				},
				ContainerID: ContainerID{
					Sources: []string{"container.id"},
				},
			},
			wantErr: false,
			match:   ".*",
			record:  defaultRecord,
		},
		{
			name: "fetch default attributes",
			len:  12,
			config: func() *Config {
				c := createDefaultConfig().(*Config)
				c.ContainerID.Sources = append(c.ContainerID.Sources, "container.id")
				return c
			}(),
			wantErr: false,
			match:   "^aws.*|^image.*|^docker.*|^labels.*",
			record:  defaultRecord,
		},
		{
			name:    "no container id path",
			len:     11,
			config:  createDefaultConfig().(*Config),
			wantErr: true,
			match:   "^aws.*|^image.*|^docker.*",
			record:  defaultRecord,
		},

		{
			name: "specify container id as as log.file.name",
			len:  34,
			config: &Config{
				Attributes: []string{
					".*",
				},
				ContainerID: ContainerID{
					Sources: []string{"log.file.name"},
				},
			},
			wantErr: false,
			match:   ".*",
			record: func() plog.Logs {
				ld := plog.NewLogs()
				ld.ResourceLogs().AppendEmpty().Resource().Attributes().PutStr("log.file.name", testcontainerID+"-json.log")
				return ld
			},
		},
		{
			name: "bad regex",
			len:  9,
			config: &Config{
				Attributes: []string{
					"?=",
				},
				ContainerID: ContainerID{
					Sources: []string{"container.id"},
				},
			},
			wantErr: true,
			match:   ".*",
			record:  defaultRecord,
		},
	}

	// define logger
	logger := zap.NewExample()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.init()
			if tt.wantErr {
				require.Error(t, err)
				return
			}
			require.NoError(t, err)

			result, err := processLogsFunc(logger, tt.config)(context.Background(), tt.record())
			require.NoError(t, err)

			var matches int
			result.ResourceLogs().At(0).Resource().Attributes().Range(func(k string, v pcommon.Value) bool {
				if regexp.MustCompile(tt.match).MatchString(k) {
					matches += 1
				}
				return true
			})

			assert.Equal(t, tt.len, matches)
			numOfAttributes := result.ResourceLogs().At(0).Resource().Attributes().Len()
			if numOfAttributes < 34 {
				assert.Equal(t, tt.len+1, numOfAttributes)
			}

		})
	}
}
