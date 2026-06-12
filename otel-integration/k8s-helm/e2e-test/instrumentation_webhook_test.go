package e2e

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/open-telemetry/opentelemetry-collector-contrib/pkg/xk8stest"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/consumer/consumertest"
	"go.opentelemetry.io/collector/pdata/ptrace"
	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

const instrumentationWebhookTraceTimeout = 3 * time.Minute

func TestE2E_InstrumentationWebhookNoCRDs(t *testing.T) {
	if os.Getenv("RUN_INSTRUMENTATION_WEBHOOK_E2E") != "1" {
		t.Skip("set RUN_INSTRUMENTATION_WEBHOOK_E2E=1 to run no-CRD instrumentation webhook e2e")
	}
	requireRequiredNodeArch := os.Getenv("REQUIRE_INSTRUMENTATION_WEBHOOK_NODE_ARCH") == "1"

	kubeconfigPath := testKubeConfig
	if kubeConfigFromEnv := os.Getenv(kubeConfigEnvVar); kubeConfigFromEnv != "" {
		kubeconfigPath = kubeConfigFromEnv
	}

	k8sClient, err := xk8stest.NewK8sClient(kubeconfigPath)
	require.NoError(t, err)

	require.NoError(t, waitForInstrumentationWebhookManager(k8sClient))

	ns := fmt.Sprintf("instrumentation-webhook-e2e-%s", uuid.NewString()[:8])
	nsObj := &unstructured.Unstructured{Object: map[string]any{
		"apiVersion": "v1",
		"kind":       "Namespace",
		"metadata": map[string]any{
			"name": ns,
		},
	}}
	_, err = k8sClient.DynamicClient.Resource(corev1.SchemeGroupVersion.WithResource("namespaces")).Create(context.Background(), nsObj, metav1.CreateOptions{})
	require.NoError(t, err)
	t.Cleanup(func() {
		_ = xk8stest.DeleteObject(k8sClient, nsObj)
	})

	tracesConsumer := new(consumertest.TracesSink)
	shutdownSink := StartUpSinks(t, ReceiverSinks{
		Traces: &TraceSinkConfig{
			Consumer: tracesConsumer,
			Ports: &ReceiverPorts{
				Grpc: 4321,
			},
		},
	})
	defer shutdownSink()

	tests := []struct {
		name              string
		annotation        string
		image             string
		port              int
		path              string
		command           []string
		expectedInit      []string
		expectedContainer string
		expectedEnv       string
		extraAnnotations  map[string]string
		requiredNodeArch  string
		skipReason        string
	}{
		{
			name:              "java",
			annotation:        "instrumentation.opentelemetry.io/inject-java",
			image:             "ghcr.io/open-telemetry/opentelemetry-operator/e2e-test-app-java:main",
			port:              8080,
			path:              "/",
			expectedInit:      []string{"opentelemetry-auto-instrumentation-java"},
			expectedContainer: "app",
			expectedEnv:       "JAVA_TOOL_OPTIONS",
		},
		{
			name:              "nodejs",
			annotation:        "instrumentation.opentelemetry.io/inject-nodejs",
			image:             "ghcr.io/open-telemetry/opentelemetry-operator/e2e-test-app-nodejs:main",
			port:              3000,
			path:              "/rolldice",
			expectedInit:      []string{"opentelemetry-auto-instrumentation-nodejs"},
			expectedContainer: "app",
			expectedEnv:       "NODE_OPTIONS",
		},
		{
			name:              "python",
			annotation:        "instrumentation.opentelemetry.io/inject-python",
			image:             "ghcr.io/open-telemetry/opentelemetry-operator/e2e-test-app-python:main",
			port:              8080,
			path:              "/",
			expectedInit:      []string{"opentelemetry-auto-instrumentation-python"},
			expectedContainer: "app",
			expectedEnv:       "PYTHONPATH",
		},
		{
			name:              "dotnet",
			annotation:        "instrumentation.opentelemetry.io/inject-dotnet",
			image:             "mcr.microsoft.com/dotnet/samples:aspnetapp",
			port:              8080,
			path:              "/",
			expectedInit:      []string{"opentelemetry-auto-instrumentation-dotnet"},
			expectedContainer: "app",
			expectedEnv:       "CORECLR_ENABLE_PROFILING",
			extraAnnotations: map[string]string{
				"instrumentation.opentelemetry.io/otel-dotnet-auto-runtime": "linux-musl-x64",
			},
			requiredNodeArch: "amd64",
			skipReason:       "the .NET auto-instrumentation profiler artifacts used by the operator are x64-only",
		},
		{
			name:              "apache",
			annotation:        "instrumentation.opentelemetry.io/inject-apache-httpd",
			image:             "ghcr.io/open-telemetry/opentelemetry-operator/e2e-test-app-apache-httpd:main",
			port:              8080,
			path:              "/",
			expectedInit:      []string{"otel-agent-source-container-clone", "otel-agent-attach-apache"},
			expectedContainer: "app",
			requiredNodeArch:  "amd64",
			skipReason:        "the Apache HTTPD auto-instrumentation image is published for x64 runtimes",
		},
		{
			name:              "nginx",
			annotation:        "instrumentation.opentelemetry.io/inject-nginx",
			image:             "nginxinc/nginx-unprivileged:1.25.3",
			port:              8080,
			path:              "/",
			expectedInit:      []string{"otel-agent-source-container-clone", "otel-agent-attach-nginx"},
			expectedContainer: "app",
			expectedEnv:       "LD_LIBRARY_PATH",
			requiredNodeArch:  "amd64",
			skipReason:        "the Nginx auto-instrumentation image is published for x64 runtimes",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.requiredNodeArch != "" && !clusterHasNodeArchitecture(t, k8sClient, tc.requiredNodeArch) {
				if requireRequiredNodeArch {
					t.Fatalf("%s signal test requires a %s node: %s", tc.name, tc.requiredNodeArch, tc.skipReason)
				}
				t.Skipf("%s signal test requires a %s node: %s", tc.name, tc.requiredNodeArch, tc.skipReason)
			}

			deployment := instrumentationWebhookDeployment(tc.name, ns, "", tc.image, tc.port, tc.path, tc.command, tc.extraAnnotations, tc.requiredNodeArch)
			created, err := k8sClient.DynamicClient.Resource(appsV1Deployments()).Namespace(ns).Create(context.Background(), deployment, metav1.CreateOptions{})
			require.NoError(t, err)
			t.Cleanup(func() {
				_ = xk8stest.DeleteObject(k8sClient, created)
			})

			baselinePod := waitForDeploymentReadyPod(t, k8sClient, ns, created.GetName(), "")
			curlPod(t, k8sClient, ns, baselinePod.GetName(), tc.port, tc.path)
			requireNoTraceForPod(t, tracesConsumer, baselinePod.GetName(), 15*time.Second)

			err = injectDeploymentInstrumentation(k8sClient, ns, created.GetName(), tc.annotation)
			require.NoError(t, err)

			instrumentedPod := waitForDeploymentReadyPod(t, k8sClient, ns, created.GetName(), baselinePod.GetName())

			for _, initName := range tc.expectedInit {
				require.Truef(t, hasContainer(instrumentedPod, "initContainers", initName), "expected init container %q in pod %s", initName, tc.name)
			}
			if tc.expectedContainer != "" {
				require.Truef(t, hasContainer(instrumentedPod, "containers", tc.expectedContainer), "expected container %q in pod %s", tc.expectedContainer, tc.name)
			}
			if tc.expectedEnv != "" {
				require.Truef(t, containerHasEnv(instrumentedPod, tc.expectedContainer, tc.expectedEnv), "expected env %q on container %q in pod %s", tc.expectedEnv, tc.expectedContainer, tc.name)
				require.Truef(t, containerHasEnv(instrumentedPod, tc.expectedContainer, "OTEL_EXPORTER_OTLP_PROTOCOL"), "expected protocol env on container %q in pod %s", tc.expectedContainer, tc.name)
			}

			curlPod(t, k8sClient, ns, instrumentedPod.GetName(), tc.port, tc.path)
			requireTraceForPod(t, tracesConsumer, instrumentedPod.GetName())
		})
	}
}

func appsV1Deployments() schema.GroupVersionResource {
	return schema.GroupVersionResource{Group: "apps", Version: "v1", Resource: "deployments"}
}

func clusterHasNodeArchitecture(t *testing.T, k8sClient *xk8stest.K8sClient, architecture string) bool {
	t.Helper()

	nodes, err := k8sClient.DynamicClient.Resource(corev1.SchemeGroupVersion.WithResource("nodes")).List(context.Background(), metav1.ListOptions{})
	require.NoError(t, err)
	require.NotEmpty(t, nodes.Items, "expected at least one Kubernetes node")
	for _, node := range nodes.Items {
		got, found, _ := unstructured.NestedString(node.Object, "status", "nodeInfo", "architecture")
		if found && got == architecture {
			return true
		}
	}
	return false
}

func waitForInstrumentationWebhookManager(k8sClient *xk8stest.K8sClient) error {
	deployments := schema.GroupVersionResource{Group: "apps", Version: "v1", Resource: "deployments"}
	return eventually(5*time.Minute, 2*time.Second, func() (bool, error) {
		list, err := k8sClient.DynamicClient.Resource(deployments).Namespace("default").List(context.Background(), metav1.ListOptions{
			LabelSelector: "app.kubernetes.io/component=instrumentation-webhook-manager",
		})
		if err != nil {
			return false, err
		}
		for _, item := range list.Items {
			ready, _, _ := unstructured.NestedInt64(item.Object, "status", "readyReplicas")
			if ready > 0 {
				return true, nil
			}
		}
		return false, nil
	})
}

func instrumentationWebhookDeployment(name, namespace, annotation, image string, port int, path string, command []string, extraAnnotations map[string]string, nodeArch string) *unstructured.Unstructured {
	appName := "instwebhook-" + name
	annotations := map[string]any{}
	if annotation != "" {
		annotations[annotation] = "true"
	}
	for k, v := range extraAnnotations {
		annotations[k] = v
	}
	container := map[string]any{
		"name":  "app",
		"image": image,
		"ports": []any{
			map[string]any{
				"name":          "http",
				"containerPort": port,
			},
		},
		"readinessProbe": map[string]any{
			"httpGet": map[string]any{
				"path": path,
				"port": port,
			},
			"initialDelaySeconds": int64(5),
			"periodSeconds":       int64(5),
			"timeoutSeconds":      int64(2),
			"failureThreshold":    int64(12),
		},
	}
	if len(command) > 0 {
		container["command"] = stringSliceToAny(command)
	}

	podSpec := map[string]any{
		"containers": []any{
			container,
		},
	}
	if nodeArch != "" {
		podSpec["nodeSelector"] = map[string]any{
			"kubernetes.io/arch": nodeArch,
		}
	}

	return &unstructured.Unstructured{Object: map[string]any{
		"apiVersion": "apps/v1",
		"kind":       "Deployment",
		"metadata": map[string]any{
			"name":      appName,
			"namespace": namespace,
		},
		"spec": map[string]any{
			"replicas": int64(1),
			"strategy": map[string]any{
				"type": "Recreate",
			},
			"selector": map[string]any{
				"matchLabels": map[string]any{
					"app": appName,
				},
			},
			"template": map[string]any{
				"metadata": map[string]any{
					"annotations": annotations,
					"labels": map[string]any{
						"app": appName,
					},
				},
				"spec": podSpec,
			},
		},
	}}
}

func stringSliceToAny(values []string) []any {
	out := make([]any, 0, len(values))
	for _, value := range values {
		out = append(out, value)
	}
	return out
}

func waitForPodReady(t *testing.T, k8sClient *xk8stest.K8sClient, namespace, podName string) {
	t.Helper()

	require.Eventuallyf(t, func() bool {
		pod, err := k8sClient.DynamicClient.Resource(corev1.SchemeGroupVersion.WithResource("pods")).Namespace(namespace).Get(context.Background(), podName, metav1.GetOptions{})
		if err != nil {
			return false
		}
		return podIsReady(pod)
	}, 3*time.Minute, 2*time.Second, "pod %s/%s did not become ready", namespace, podName)
}

func waitForDeploymentReadyPod(t *testing.T, k8sClient *xk8stest.K8sClient, namespace, deploymentName, excludedPodName string) *unstructured.Unstructured {
	t.Helper()

	var readyPod *unstructured.Unstructured
	require.Eventuallyf(t, func() bool {
		pods, err := k8sClient.DynamicClient.Resource(corev1.SchemeGroupVersion.WithResource("pods")).Namespace(namespace).List(context.Background(), metav1.ListOptions{
			LabelSelector: "app=" + deploymentName,
		})
		if err != nil {
			return false
		}
		for i := range pods.Items {
			pod := &pods.Items[i]
			if pod.GetName() == excludedPodName {
				continue
			}
			if podIsReady(pod) {
				readyPod = pod
				return true
			}
		}
		return false
	}, 3*time.Minute, 2*time.Second, "deployment %s/%s did not produce a ready pod", namespace, deploymentName)

	return readyPod
}

func podIsReady(pod *unstructured.Unstructured) bool {
	status, ok := pod.Object["status"].(map[string]any)
	if !ok || status["phase"] != string(corev1.PodRunning) {
		return false
	}
	statuses, found, _ := unstructured.NestedSlice(pod.Object, "status", "containerStatuses")
	if !found || len(statuses) == 0 {
		return false
	}
	for _, raw := range statuses {
		containerStatus, ok := raw.(map[string]any)
		if !ok || containerStatus["ready"] != true {
			return false
		}
	}
	return true
}

func injectDeploymentInstrumentation(k8sClient *xk8stest.K8sClient, namespace, deploymentName, annotation string) error {
	deployment, err := k8sClient.DynamicClient.Resource(appsV1Deployments()).Namespace(namespace).Get(context.Background(), deploymentName, metav1.GetOptions{})
	if err != nil {
		return err
	}

	spec := deployment.Object["spec"].(map[string]any)
	template := spec["template"].(map[string]any)
	metadata := template["metadata"].(map[string]any)
	annotations, ok := metadata["annotations"].(map[string]any)
	if !ok {
		annotations = map[string]any{}
		metadata["annotations"] = annotations
	}
	annotations[annotation] = "true"
	annotations["instrumentation-webhook-e2e.coralogix.com/rollout"] = time.Now().Format(time.RFC3339Nano)

	_, err = k8sClient.DynamicClient.Resource(appsV1Deployments()).Namespace(namespace).Update(context.Background(), deployment, metav1.UpdateOptions{})
	return err
}

func curlPod(t *testing.T, k8sClient *xk8stest.K8sClient, namespace, targetPod string, port int, path string) {
	t.Helper()

	target, err := k8sClient.DynamicClient.Resource(corev1.SchemeGroupVersion.WithResource("pods")).Namespace(namespace).Get(context.Background(), targetPod, metav1.GetOptions{})
	require.NoError(t, err)

	podIP, found, _ := unstructured.NestedString(target.Object, "status", "podIP")
	require.Truef(t, found && podIP != "", "pod %s/%s does not have an IP", namespace, targetPod)

	requestPodName := fmt.Sprintf("curl-%s-%s", targetPod, uuid.NewString()[:6])
	requestPod := &unstructured.Unstructured{Object: map[string]any{
		"apiVersion": "v1",
		"kind":       "Pod",
		"metadata": map[string]any{
			"name":      requestPodName,
			"namespace": namespace,
			"labels": map[string]any{
				"app": "instrumentation-webhook-curl",
			},
		},
		"spec": map[string]any{
			"restartPolicy": "Never",
			"containers": []any{
				map[string]any{
					"name":  "curl",
					"image": "curlimages/curl:8.10.1",
					"command": []any{
						"sh",
						"-c",
						fmt.Sprintf("for i in $(seq 1 30); do curl -fsS --max-time 5 http://%s:%d%s && exit 0; sleep 2; done; exit 1", podIP, port, path),
					},
				},
			},
		},
	}}

	created, err := k8sClient.DynamicClient.Resource(corev1.SchemeGroupVersion.WithResource("pods")).Namespace(namespace).Create(context.Background(), requestPod, metav1.CreateOptions{})
	require.NoError(t, err)
	t.Cleanup(func() {
		_ = xk8stest.DeleteObject(k8sClient, created)
	})

	require.Eventuallyf(t, func() bool {
		got, err := k8sClient.DynamicClient.Resource(corev1.SchemeGroupVersion.WithResource("pods")).Namespace(namespace).Get(context.Background(), requestPodName, metav1.GetOptions{})
		if err != nil {
			return false
		}
		phase, found, _ := unstructured.NestedString(got.Object, "status", "phase")
		if phase == string(corev1.PodFailed) {
			t.Logf("curl pod %s failed", requestPodName)
		}
		return found && phase == string(corev1.PodSucceeded)
	}, 2*time.Minute, 2*time.Second, "curl pod %s failed to request %s", requestPodName, targetPod)
}

func requireNoTraceForPod(t *testing.T, tracesConsumer *consumertest.TracesSink, podName string, duration time.Duration) {
	t.Helper()

	require.Neverf(t, func() bool {
		return tracesContainPod(tracesConsumer.AllTraces(), podName)
	}, duration, time.Second, "received traces for uninstrumented pod %s", podName)
}

func requireTraceForPod(t *testing.T, tracesConsumer *consumertest.TracesSink, podName string) {
	t.Helper()

	require.Eventuallyf(t, func() bool {
		return tracesContainPod(tracesConsumer.AllTraces(), podName)
	}, instrumentationWebhookTraceTimeout, 2*time.Second, "did not receive traces for instrumented pod %s", podName)
}

func tracesContainPod(batches []ptrace.Traces, podName string) bool {
	for _, batch := range batches {
		for i := 0; i < batch.ResourceSpans().Len(); i++ {
			resource := batch.ResourceSpans().At(i).Resource()
			if attr, ok := resource.Attributes().Get("k8s.pod.name"); ok && attr.AsString() == podName {
				return true
			}
			if attr, ok := resource.Attributes().Get("service.name"); ok && attr.AsString() == podName {
				return true
			}
		}
	}
	return false
}

func hasContainer(obj *unstructured.Unstructured, field, name string) bool {
	containers, found, _ := unstructured.NestedSlice(obj.Object, "spec", field)
	if !found {
		return false
	}
	for _, raw := range containers {
		container, ok := raw.(map[string]any)
		if ok && container["name"] == name {
			return true
		}
	}
	return false
}

func containerHasEnv(obj *unstructured.Unstructured, containerName, envName string) bool {
	containers, found, _ := unstructured.NestedSlice(obj.Object, "spec", "containers")
	if !found {
		return false
	}
	for _, raw := range containers {
		container, ok := raw.(map[string]any)
		if !ok || container["name"] != containerName {
			continue
		}
		envs, ok := container["env"].([]any)
		if !ok {
			return false
		}
		for _, rawEnv := range envs {
			env, ok := rawEnv.(map[string]any)
			if ok && env["name"] == envName {
				return true
			}
		}
	}
	return false
}

func eventually(timeout, interval time.Duration, check func() (bool, error)) error {
	deadline := time.Now().Add(timeout)
	var lastErr error
	for time.Now().Before(deadline) {
		ok, err := check()
		if err != nil {
			if !apierrors.IsNotFound(err) {
				lastErr = err
			}
		}
		if ok {
			return nil
		}
		time.Sleep(interval)
	}
	if lastErr != nil {
		return lastErr
	}
	return fmt.Errorf("condition not met within %s", timeout)
}
