// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0

package e2e

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/open-telemetry/opentelemetry-collector-contrib/pkg/xk8stest"
	"github.com/stretchr/testify/require"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

const windowsLogMarker = "WINDOWS-OTEL-LOG-CHECK"

func TestE2E_WindowsLogCollection(t *testing.T) {
	if !isWindowsE2EEnvironment() {
		t.Skip("windows harness checks require E2E_ENVIRONMENT=windows")
	}

	k8sClient := newE2EK8sClient(t)
	requireWindowsDebugSettings(t, k8sClient)
	requireWindowsLogCollection(t, k8sClient)
}

func newE2EK8sClient(t *testing.T) *xk8stest.K8sClient {
	t.Helper()

	client, err := xk8stest.NewK8sClient(e2eKubeconfigPath())
	require.NoError(t, err)
	return client
}

func e2eKubeconfigPath() string {
	if kubeConfigFromEnv := os.Getenv(kubeConfigEnvVar); kubeConfigFromEnv != "" {
		return kubeConfigFromEnv
	}
	return testKubeConfig
}

func windowsAgentNamespace() string {
	if ns := os.Getenv("E2E_WINDOWS_AGENT_NAMESPACE"); ns != "" {
		return ns
	}
	return agentCollectorNamespace()
}

func windowsAgentConfigMapName() string {
	if name := os.Getenv("E2E_WINDOWS_AGENT_CONFIGMAP"); name != "" {
		return name
	}
	return "coralogix-opentelemetry-windows-agent"
}

func windowsAgentDaemonSetName() string {
	if name := os.Getenv("E2E_WINDOWS_AGENT_DAEMONSET"); name != "" {
		return name
	}
	return "coralogix-opentelemetry-windows-agent"
}

func windowsLogGeneratorNamespace() string {
	if ns := os.Getenv("E2E_WINDOWS_LOG_GENERATOR_NAMESPACE"); ns != "" {
		return ns
	}
	return "default"
}

func requireWindowsDebugSettings(t *testing.T, client *xk8stest.K8sClient) {
	t.Helper()

	configMaps := schema.GroupVersionResource{Group: "", Version: "v1", Resource: "configmaps"}
	configMap, err := client.DynamicClient.Resource(configMaps).
		Namespace(windowsAgentNamespace()).
		Get(context.Background(), windowsAgentConfigMapName(), metav1.GetOptions{})
	require.NoError(t, err)

	config := strings.Join(configMapData(configMap), "\n")
	require.Contains(t, config, "verbosity: detailed", "debug exporter must use detailed verbosity")
	require.Contains(t, config, "- debug", "debug exporter must be enabled in a pipeline")
	require.True(t,
		strings.Contains(config, "level: debug") || strings.Contains(config, "level: 'debug'") || strings.Contains(config, `level: "debug"`),
		"collector log level must be debug",
	)
}

func configMapData(configMap *unstructured.Unstructured) []string {
	data, _, _ := unstructured.NestedStringMap(configMap.Object, "data")
	values := make([]string, 0, len(data))
	for _, value := range data {
		values = append(values, value)
	}
	return values
}

func requireWindowsLogCollection(t *testing.T, client *xk8stest.K8sClient) {
	t.Helper()

	deployment := createWindowsLogGenerator(t, client)
	t.Cleanup(func() {
		deleteWindowsLogGenerator(t, client, deployment)
	})

	require.Eventually(t, func() bool {
		return kubectlLogsContain(t, "deployment/windows-log-generator", windowsLogGeneratorNamespace(), "--tail=60", windowsLogMarker)
	}, 2*time.Minute, 5*time.Second, "Windows log generator did not emit %q", windowsLogMarker)

	require.Eventually(t, func() bool {
		return kubectlLogsContain(t, fmt.Sprintf("daemonset/%s", windowsAgentDaemonSetName()), windowsAgentNamespace(), "--since=20m", "--tail=4000", "--max-log-requests=20", windowsLogMarker)
	}, 5*time.Minute, 10*time.Second, "Windows collector debug exporter did not emit %q", windowsLogMarker)
}

func createWindowsLogGenerator(t *testing.T, client *xk8stest.K8sClient) *unstructured.Unstructured {
	t.Helper()

	deployments := schema.GroupVersionResource{Group: "apps", Version: "v1", Resource: "deployments"}
	namespace := windowsLogGeneratorNamespace()
	manifestPath := filepath.Join("testdata", "windows-log-generator.yaml")
	manifest, err := os.ReadFile(manifestPath)
	require.NoError(t, err)

	obj := decodeManifestObject(t, manifest, manifestPath)
	obj.SetNamespace(namespace)

	deleteWindowsLogGenerator(t, client, obj)

	created, err := client.DynamicClient.Resource(deployments).Namespace(namespace).
		Create(context.Background(), obj, metav1.CreateOptions{})
	require.NoError(t, err)

	require.Eventually(t, func() bool {
		current, err := client.DynamicClient.Resource(deployments).Namespace(namespace).
			Get(context.Background(), created.GetName(), metav1.GetOptions{})
		if err != nil {
			return false
		}
		readyReplicas, _, _ := unstructured.NestedInt64(current.Object, "status", "readyReplicas")
		availableReplicas, _, _ := unstructured.NestedInt64(current.Object, "status", "availableReplicas")
		return readyReplicas > 0 || availableReplicas > 0
	}, 15*time.Minute, 10*time.Second, "Windows log generator deployment did not become ready")

	return created
}

func deleteWindowsLogGenerator(t *testing.T, client *xk8stest.K8sClient, deployment *unstructured.Unstructured) {
	t.Helper()

	if deployment == nil {
		return
	}
	deployments := schema.GroupVersionResource{Group: "apps", Version: "v1", Resource: "deployments"}
	deletePolicy := metav1.DeletePropagationForeground
	err := client.DynamicClient.Resource(deployments).Namespace(deployment.GetNamespace()).
		Delete(context.Background(), deployment.GetName(), metav1.DeleteOptions{PropagationPolicy: &deletePolicy})
	if err != nil && !apierrors.IsNotFound(err) {
		require.NoError(t, err)
	}
}

func kubectlLogsContain(t *testing.T, resource string, namespace string, args ...string) bool {
	t.Helper()

	commandArgs := []string{"--namespace", namespace, "logs", resource}
	commandArgs = append(commandArgs, args[:len(args)-1]...)
	needle := args[len(args)-1]

	cmd := exec.Command("kubectl", commandArgs...)
	if kubeconfig := e2eKubeconfigPath(); kubeconfig != "" {
		cmd.Env = append(os.Environ(), fmt.Sprintf("KUBECONFIG=%s", kubeconfig))
	}
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Logf("kubectl logs %s failed: %v: %s", resource, err, string(output))
		return false
	}
	if strings.Contains(string(output), needle) {
		return true
	}
	t.Logf("kubectl logs %s missing %q", resource, needle)
	return false
}
