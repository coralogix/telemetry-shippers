package e2e_test

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	intege2e "coralogix.com/otel-integration/e2e"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/consumer/consumertest"
	"gopkg.in/yaml.v3"
)

const (
	telemetrygenImage = "ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest"
	collectorPort     = 4317
)

func TestRenderedConfigShipsTracesMetricsAndLogs(t *testing.T) {
	repoRoot := filepath.Clean(filepath.Join(testDir(t), ".."))
	workDir := tempWorkDir(t, repoRoot)
	valuesPath := filepath.Join(workDir, "values-smoke.yaml")

	sinks := startMockSinks(t)
	renderedConfig := renderSmokeConfig(t, repoRoot, workDir, sinks)
	collectorImage := renderedCollectorImage(t, repoRoot, valuesPath)

	validateRenderedConfig(t, repoRoot, collectorImage, renderedConfig)

	containerName := fmt.Sprintf("otel-linux-standalone-smoke-%d", time.Now().UnixNano())
	startCollector(t, repoRoot, collectorImage, containerName, renderedConfig)
	t.Cleanup(func() { stopContainer(t, repoRoot, containerName) })

	waitForPort(t, "127.0.0.1:4317")

	runTelemetrygen(t, repoRoot, "traces", "--traces=2", "--service=smoke-traces")
	runTelemetrygen(t, repoRoot, "metrics", "--metrics=2", "--service=smoke-metrics", "--otlp-metric-name=smoke_metric")
	runTelemetrygen(t, repoRoot, "logs", "--logs=2", "--service=smoke-logs", "--body=smoke-log-line")

	require.Eventually(t, func() bool { return len(sinks.Traces.Consumer.AllTraces()) > 0 }, 30*time.Second, 500*time.Millisecond)
	require.Eventually(t, func() bool { return len(sinks.Metrics.Consumer.AllMetrics()) > 0 }, 30*time.Second, 500*time.Millisecond)
	require.Eventually(t, func() bool { return len(sinks.Logs.Consumer.AllLogs()) > 0 }, 30*time.Second, 500*time.Millisecond)
}

func renderSmokeConfig(t *testing.T, repoRoot, workDir string, sinks intege2e.ReceiverSinks) string {
	t.Helper()

	valuesPath := filepath.Join(repoRoot, "values.yaml")
	patchedValuesPath := filepath.Join(workDir, "values-smoke.yaml")
	configOutputDir := filepath.Join(workDir, "rendered")
	configPath := filepath.Join(configOutputDir, "otel-config.yaml")

	writeSmokeValuesFromBase(t, valuesPath, patchedValuesPath, sinks)

	runCmd(t, repoRoot, nil,
		"make", "otel-config",
		"VALUES_FILE="+patchedValuesPath,
		"OUTPUT_DIR="+configOutputDir,
	)

	_, err := os.Stat(configPath)
	require.NoError(t, err)

	return configPath
}

func renderedCollectorImage(t *testing.T, repoRoot, valuesPath string) string {
	t.Helper()

	manifest := runCmd(t, repoRoot, nil, "helm", "template", "eco-system-linux", ".", "-f", valuesPath)
	decoder := yaml.NewDecoder(strings.NewReader(manifest))

	for {
		var doc map[string]any
		err := decoder.Decode(&doc)
		if errors.Is(err, io.EOF) {
			break
		}
		require.NoError(t, err)

		kind, _ := doc["kind"].(string)
		if kind != "DaemonSet" && kind != "Deployment" && kind != "StatefulSet" {
			continue
		}

		image := nestedString(doc, "spec", "template", "spec", "containers", "0", "image")
		if image != "" {
			return image
		}
	}

	require.FailNow(t, "failed to resolve collector image from rendered chart")
	return ""
}

func writeSmokeValuesFromBase(t *testing.T, basePath, outPath string, sinks intege2e.ReceiverSinks) {
	t.Helper()

	raw, err := os.ReadFile(basePath)
	require.NoError(t, err)

	values := map[string]any{}
	require.NoError(t, yaml.Unmarshal(raw, &values))

	set(values, []string{"opentelemetry-agent", "presets", "fleetManagement", "enabled"}, false)
	set(values, []string{"opentelemetry-agent", "presets", "journaldReceiver", "enabled"}, false)
	set(values, []string{"opentelemetry-agent", "presets", "systemdReceiver", "enabled"}, false)

	set(values, []string{"opentelemetry-agent", "config", "exporters", "coralogix", "traces", "endpoint"}, hostEndpoint(sinks.Traces.Ports.Grpc))
	set(values, []string{"opentelemetry-agent", "config", "exporters", "coralogix", "traces", "tls", "insecure"}, true)
	set(values, []string{"opentelemetry-agent", "config", "exporters", "coralogix", "metrics", "endpoint"}, hostEndpoint(sinks.Metrics.Ports.Grpc))
	set(values, []string{"opentelemetry-agent", "config", "exporters", "coralogix", "metrics", "tls", "insecure"}, true)
	set(values, []string{"opentelemetry-agent", "config", "exporters", "coralogix", "logs", "endpoint"}, hostEndpoint(sinks.Logs.Ports.Grpc))
	set(values, []string{"opentelemetry-agent", "config", "exporters", "coralogix", "logs", "tls", "insecure"}, true)
	set(values, []string{"opentelemetry-agent", "config", "exporters", "coralogix/resource_catalog", "logs", "endpoint"}, hostEndpoint(sinks.Logs.Ports.Grpc))
	set(values, []string{"opentelemetry-agent", "config", "exporters", "coralogix/resource_catalog", "logs", "tls", "insecure"}, true)

	encoded, err := yaml.Marshal(values)
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(outPath, encoded, 0o600))
}

func startMockSinks(t *testing.T) intege2e.ReceiverSinks {
	t.Helper()

	sinks := intege2e.ReceiverSinks{
		Traces: &intege2e.TraceSinkConfig{
			Ports:    &intege2e.ReceiverPorts{Grpc: 15417, Http: 16417},
			Consumer: new(consumertest.TracesSink),
		},
		Metrics: &intege2e.MetricSinkConfig{
			Ports:    &intege2e.ReceiverPorts{Grpc: 15418, Http: 16418},
			Consumer: new(consumertest.MetricsSink),
		},
		Logs: &intege2e.LogSinkConfig{
			Ports:    &intege2e.ReceiverPorts{Grpc: 15419, Http: 16419},
			Consumer: new(consumertest.LogsSink),
		},
	}

	t.Cleanup(intege2e.StartUpSinks(t, sinks))
	return sinks
}

func validateRenderedConfig(t *testing.T, repoRoot, collectorImage, configPath string) {
	t.Helper()

	runCmd(
		t,
		repoRoot,
		nil,
		"docker", "run", "--rm",
		"-e", "CORALOGIX_PRIVATE_KEY=smoke-test-key",
		"-v", configPath+":/cfg/otel-config.yaml:ro",
		collectorImage,
		"validate",
		"--config=file:/cfg/otel-config.yaml",
	)
}

func startCollector(t *testing.T, repoRoot, collectorImage, containerName, configPath string) {
	t.Helper()

	stopContainer(t, repoRoot, containerName)

	runCmd(
		t,
		repoRoot,
		nil,
		"docker", "run", "--rm", "--detach",
		"--name", containerName,
		"-p", fmt.Sprintf("%d:%d", collectorPort, collectorPort),
		"-v", configPath+":/cfg/otel-config.yaml:ro",
		"-e", "CORALOGIX_PRIVATE_KEY=smoke-test-key",
		"-e", "OTEL_LISTEN_INTERFACE=0.0.0.0",
		collectorImage,
		"--config=/cfg/otel-config.yaml",
	)
}

func runTelemetrygen(t *testing.T, repoRoot, signal string, extraArgs ...string) {
	t.Helper()

	args := []string{
		"run", "--rm",
		telemetrygenImage,
		signal,
		"--otlp-endpoint=host.docker.internal:4317",
		"--otlp-insecure",
		"--duration=3s",
		"--rate=1",
		"--workers=1",
	}
	args = append(args, extraArgs...)

	runCmd(t, repoRoot, nil, "docker", args...)
}

func waitForPort(t *testing.T, endpoint string) {
	t.Helper()

	require.Eventually(t, func() bool {
		conn, err := net.DialTimeout("tcp", endpoint, time.Second)
		if err != nil {
			return false
		}
		_ = conn.Close()
		return true
	}, 30*time.Second, 500*time.Millisecond)
}

func stopContainer(t *testing.T, repoRoot, containerName string) {
	t.Helper()
	cmd := exec.Command("docker", "rm", "-f", containerName)
	cmd.Dir = repoRoot
	_ = cmd.Run()
}

func runCmd(t *testing.T, dir string, env []string, name string, args ...string) string {
	t.Helper()

	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	if env != nil {
		cmd.Env = append(os.Environ(), env...)
	}

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err := cmd.Run()
	if err != nil {
		require.FailNowf(t, "command failed", "command: %s %s\nstdout:\n%s\nstderr:\n%s", name, strings.Join(args, " "), stdout.String(), stderr.String())
	}

	return stdout.String()
}

func set(root map[string]any, path []string, value any) {
	current := root
	for _, key := range path[:len(path)-1] {
		next, ok := current[key]
		if !ok {
			child := map[string]any{}
			current[key] = child
			current = child
			continue
		}

		child, ok := next.(map[string]any)
		if !ok {
			child = map[string]any{}
			current[key] = child
		}
		current = child
	}
	current[path[len(path)-1]] = value
}

func hostEndpoint(port int) string {
	return fmt.Sprintf("host.docker.internal:%d", port)
}

func nestedString(root map[string]any, path ...string) string {
	var current any = root
	for _, part := range path {
		switch node := current.(type) {
		case map[string]any:
			current = node[part]
		case []any:
			if part != "0" || len(node) == 0 {
				return ""
			}
			current = node[0]
		default:
			return ""
		}
	}

	value, _ := current.(string)
	return value
}

func tempWorkDir(t *testing.T, repoRoot string) string {
	t.Helper()
	dir, err := os.MkdirTemp(repoRoot, ".smoke-e2e-")
	require.NoError(t, err)
	t.Cleanup(func() { _ = os.RemoveAll(dir) })
	return dir
}

func testDir(t *testing.T) string {
	t.Helper()
	dir, err := os.Getwd()
	require.NoError(t, err)
	return dir
}
