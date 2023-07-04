package ecslogresourcedetectionprocessor

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
	"ContainerARN": "arn:aws:ecs:eu-west-1:035955823196:container/cds-305/ec7ff82b7a3a44a5bbbe9bcf11daee33/cc1c133f-bd1f-4006-8dae-4cd8a3f54f19",
	"CreatedAt": "2023-06-22T12:41:18.315883278Z",
	"DesiredStatus": "RUNNING",
	"DockerId": "196a0e6abfce1e31ee24b65e97875f089878dd7d1d7e9f15155d6094c8b908f5",
	"DockerName": "ecs-cadvisor-task-definition-7-cadvisor-bae592b5e4c1a3bb3800",
	"Image": "gcr.io/cadvisor/cadvisor:latest",
	"ImageID": "sha256:68c29634fe49724f94ed34f18224316f776392f7a5a4014969ac5798a2ec96dc",
	"KnownStatus": "RUNNING",
	"Labels": {
	  "com.amazonaws.ecs.cluster": "cds-305",
	  "com.amazonaws.ecs.container-name": "cadvisor",
	  "com.amazonaws.ecs.task-arn": "arn:aws:ecs:eu-west-1:035955823196:task/cds-305/ec7ff82b7a3a44a5bbbe9bcf11daee33",
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

func mockMetadataEndpoint(w http.ResponseWriter, r *http.Request) {
	var m map[string]any
	json.Unmarshal([]byte(payload), &m)
	sc := http.StatusOK
	// w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(sc)
	json.NewEncoder(w).Encode(m)
}

func TestMain(m *testing.M) {
	// setup()
	server := httptest.NewServer(http.HandlerFunc(mockMetadataEndpoint))
	ecsMetadataHandler = metadataHandler{
		endpoints: map[string][]string{
			"0123456789": {server.URL},
		},
	}

	code := m.Run()
	server.Close()
	os.Exit(code)
}

func TestFormatLabels(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{
			input:    "Labels.com.amazonaws.ecs.cluster",
			expected: "ecs.cluster",
		},
		{
			input:    "ContainerARN",
			expected: "container.arn",
		},
		{
			input:    "Networks.0.IPv4Addresses.0",
			expected: "networks.0.ipv4.addresses.0",
		},
		{
			input:    "Image",
			expected: "image",
		},
	}

	for _, test := range tests {
		result := formatLabel(test.input)
		if result != test.expected {
			t.Errorf("Input: %s\nExpected: %s\nGot: %s\n", test.input, test.expected, result)
		}
	}
}

func TestMetadataHandlerGet(t *testing.T) {
	v, ok := ecsMetadataHandler.get("0123456789")
	assert.True(t, ok)
	assert.Len(t, v, 1)

	resp, err := http.Get(v[0])
	assert.NoError(t, err)
	assert.Equal(t, http.StatusOK, resp.StatusCode)

	var got map[string]any
	var expected map[string]any
	assert.NoError(t, json.NewDecoder(resp.Body).Decode(&got))
	assert.NoError(t, json.Unmarshal([]byte(payload), &expected))
	assert.Equal(t, expected, got)

}

func TestProcessLogFunc(t *testing.T) {
	tests := []struct {
		name    string
		config  *Config
		wantErr bool
		len     int
		match   string
	}{
		{
			name: "fetch all attributes starting with ecs",
			len:  5,
			config: &Config{
				Attributes: []string{
					"^ecs.*",
				},
			},
			wantErr: false,
			match:   "^ecs.*",
		},
		{
			name: "fetch all attributes",
			len:  33,
			config: &Config{
				Attributes: []string{
					".*",
				},
			},
			wantErr: false,
			match:   ".*",
		},
		{
			name:    "fetch default attributes",
			len:     9,
			config:  createDefaultConfig().(*Config),
			wantErr: false,
			match:   "^ecs.*|^image.*|^docker.*",
		},
		{
			name: "bad regex",
			len:  9,
			config: &Config{
				Attributes: []string{
					"?=",
				},
			},
			wantErr: true,
			match:   ".*",
		},
	}

	// define logger
	logger := zap.NewExample()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ld := plog.NewLogs()
			ld.ResourceLogs().AppendEmpty().Resource().Attributes().PutStr("container.id", "0123456789")
			result, err := processLogsFunc(logger, tt.config)(context.Background(), ld)
			if tt.wantErr {
				require.Error(t, err)
				return
			}

			var matches int
			result.ResourceLogs().At(0).Resource().Attributes().Range(func(k string, v pcommon.Value) bool {
				// fmt.Println(k, v.AsString())
				if regexp.MustCompile(tt.match).MatchString(k) {
					matches += 1
				}
				return true
			})

			assert.Equal(t, tt.len, matches)
			numOfAttributes := result.ResourceLogs().At(0).Resource().Attributes().Len()
			if numOfAttributes < 33 {
				assert.Equal(t, tt.len+1, numOfAttributes)
			}

		})
	}
}
