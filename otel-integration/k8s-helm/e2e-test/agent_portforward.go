package e2e

import (
	"bytes"
	"context"
	"fmt"
	"net"
	"os"
	"os/exec"
	"testing"
	"time"

	"coralogix.com/otel-integration/e2e/internal/testhelpers"
	"github.com/open-telemetry/opentelemetry-collector-contrib/pkg/xk8stest"
	"github.com/stretchr/testify/require"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func agentCollectorNamespace() string {
	if ns := os.Getenv("E2E_AGENT_NAMESPACE"); ns != "" {
		return ns
	}
	return "default"
}

func agentServiceName() string {
	if name := os.Getenv("E2E_AGENT_SERVICE"); name != "" {
		return name
	}
	return "coralogix-opentelemetry"
}

func waitForAgentCollectorPod(t *testing.T, k8sClient *xk8stest.K8sClient, namespace string) {
	t.Helper()

	require.Eventually(t, func() bool {
		pods, err := k8sClient.DynamicClient.Resource(corev1.SchemeGroupVersion.WithResource("pods")).Namespace(namespace).List(context.Background(), metav1.ListOptions{
			LabelSelector: "component=agent-collector",
		})
		require.NoError(t, err)
		if len(pods.Items) == 0 {
			return false
		}
		for _, pod := range pods.Items {
			status, ok := pod.Object["status"].(map[string]any)
			if !ok {
				continue
			}
			phase, _ := status["phase"].(string)
			if phase == string(corev1.PodRunning) {
				return true
			}
		}
		return false
	}, 2*time.Minute, 2*time.Second, "agent collector pod not ready")
}

func startAgentOTLPPortForward(t *testing.T, k8sClient *xk8stest.K8sClient, kubeconfigPath string, remotePort int) (int, func()) {
	t.Helper()

	agentNamespace := agentCollectorNamespace()
	t.Logf("Waiting for agent collector in namespace=%s", agentNamespace)
	waitForAgentCollectorPod(t, k8sClient, agentNamespace)
	t.Log("Agent collector is running")

	localPort, stopPF := startPortForward(
		t,
		kubeconfigPath,
		agentNamespace,
		fmt.Sprintf("svc/%s", agentServiceName()),
		remotePort,
	)
	t.Logf("Port forward established on 127.0.0.1:%d -> %s/%s:%d", localPort, agentNamespace, agentServiceName(), remotePort)
	return localPort, stopPF
}

func startPortForward(t *testing.T, kubeconfigPath, namespace, resource string, remotePort int) (int, func()) {
	t.Helper()

	localPort := testhelpers.GetFreePort(t)
	args := []string{
		"--namespace", namespace,
		"port-forward",
		"--address", "127.0.0.1",
		resource,
		fmt.Sprintf("%d:%d", localPort, remotePort),
	}

	ctx, cancel := context.WithCancel(context.Background())
	cmd := exec.CommandContext(ctx, "kubectl", args...)
	if kubeconfigPath != "" {
		cmd.Env = append(os.Environ(), fmt.Sprintf("KUBECONFIG=%s", kubeconfigPath))
	}

	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = &output

	require.NoError(t, cmd.Start(), "failed to start kubectl port-forward: %s", output.String())

	doneCh := make(chan error, 1)
	go func() {
		doneCh <- cmd.Wait()
	}()

	waitForLocalPort(t, localPort, doneCh, &output)

	cleanup := func() {
		cancel()
		select {
		case <-doneCh:
		case <-time.After(5 * time.Second):
			if cmd.Process != nil {
				_ = cmd.Process.Kill()
			}
			t.Logf("timed out waiting for kubectl port-forward to exit; output: %s", output.String())
		}
	}
	return localPort, cleanup
}

func waitForLocalPort(t *testing.T, port int, done <-chan error, output *bytes.Buffer) {
	t.Helper()
	deadline := time.Now().Add(15 * time.Second)

	for time.Now().Before(deadline) {
		select {
		case err := <-done:
			require.NoErrorf(t, err, "port-forward exited early: %s", output.String())
			return
		default:
		}

		conn, err := net.DialTimeout("tcp", fmt.Sprintf("127.0.0.1:%d", port), 250*time.Millisecond)
		if err == nil {
			conn.Close()
			return
		}
		time.Sleep(150 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for port-forward on port %d: %s", port, output.String())
}
