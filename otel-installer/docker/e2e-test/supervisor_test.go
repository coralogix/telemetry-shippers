package e2e_test

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"slices"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/open-telemetry/opamp-go/protobufs"
	"github.com/open-telemetry/opamp-go/server"
	"github.com/open-telemetry/opamp-go/server/types"
	"github.com/stretchr/testify/require"
	"go.uber.org/zap"
	"go.uber.org/zap/zaptest"
)

const (
	opampPort = 4320
	// Must match the path the installer renders into supervisor.yaml; the
	// production Coralogix endpoint is /opamp/v1, not upstream's /v1/opamp.
	opampPath = "/opamp/v1"

	containerName = "coralogix-otel-collector"

	// A validation-failing supervisor crashes and Docker restarts it within
	// this window (12x5s); deliberate, do not shorten.
	livenessWindow = 60 * time.Second
	reportTimeout  = 3 * time.Minute
)

// TestSupervisorReportsHealthyOverOpAMP installs the Docker Supervisor against
// an in-process OpAMP server and asserts the protocol-grade health signal: the
// supervisor reports a healthy managed collector, stays healthy, keeps one
// identity, and the container never restarts (CX-69000 regression guard).
func TestSupervisorReportsHealthyOverOpAMP(t *testing.T) {
	root := repoRoot(t)
	_, privateKey := coralogixEnv()
	recorder := startOpAMPServer(t, "Bearer "+privateKey)
	endpoint := fmt.Sprintf("http://%s:%d%s", resolveHostEndpoint(t, root), opampPort, opampPath)

	installSupervisor(t, root, endpoint)
	assertRenderedSupervisorConfig(t, endpoint)
	assertContainerStaysUp(t)

	// The supervisor publishes healthy=false by design before the collector's
	// first real report, so wait for a healthy one rather than any report.
	require.Eventually(t, func() bool {
		return firstHealthyReport(recorder.snapshot()) >= 0
	}, reportTimeout, 2*time.Second, "supervisor never reported a healthy agent over OpAMP")

	reports := recorder.snapshot()
	for _, report := range reports[firstHealthyReport(reports):] {
		require.Falsef(t, report.Healthy != nil && !*report.Healthy, "agent health flipped unhealthy after first healthy report: %s", report)
	}
	require.Len(t, distinctInstanceUIDs(reports), 1, "supervisor re-registered with multiple instance uids (storage churn?)")
	require.True(t, slices.ContainsFunc(reports, func(r reportedReport) bool { return r.HasDescription }), "no AgentDescription reported")
	require.True(t, slices.ContainsFunc(reports, func(r reportedReport) bool { return r.HasEffectiveConfig }), "no EffectiveConfig reported")
	// Nothing was offered, so FAILED means a remote config path misbehaved.
	require.False(t, slices.ContainsFunc(reports, func(r reportedReport) bool {
		return r.RemoteCfgStat == protobufs.RemoteConfigStatuses_RemoteConfigStatuses_FAILED.String()
	}), "supervisor reported remote config FAILED without an offer")

	matched, mismatched := recorder.bearerTokenSeen()
	require.True(t, matched, "installer-rendered Authorization Bearer header never reached the OpAMP server")
	require.False(t, mismatched, "an OpAMP request arrived without the installer-rendered Bearer header")
}

// TestSupervisorReportsPoisonedRemoteConfig proves the guard has teeth: once
// healthy, the agent is offered a remote config the collector cannot load, and
// the supervisor must report it as FAILED or the agent as unhealthy.
func TestSupervisorReportsPoisonedRemoteConfig(t *testing.T) {
	root := repoRoot(t)
	_, privateKey := coralogixEnv()
	recorder := startOpAMPServer(t, "Bearer "+privateKey)
	endpoint := fmt.Sprintf("http://%s:%d%s", resolveHostEndpoint(t, root), opampPort, opampPath)

	installSupervisor(t, root, endpoint)
	require.Eventually(t, func() bool {
		return firstHealthyReport(recorder.snapshot()) >= 0
	}, reportTimeout, 2*time.Second, "supervisor never reported a healthy agent over OpAMP")

	// An unknown component type fails config unmarshalling whatever user the
	// collector runs as, unlike a privileged-port bind.
	poisonedConfig := []byte("receivers:\n  poisoned_by_e2e_test: {}\n")
	hash := sha256.Sum256(poisonedConfig)
	recorder.offerRemoteConfig(poisonedConfig, hash[:])

	require.Eventually(t, func() bool {
		return slices.ContainsFunc(recorder.snapshot(), func(r reportedReport) bool {
			return r.SentAfterOfferDelivered &&
				(r.RemoteCfgStat == protobufs.RemoteConfigStatuses_RemoteConfigStatuses_FAILED.String() ||
					(r.Healthy != nil && !*r.Healthy))
		})
	}, reportTimeout, 2*time.Second, "supervisor accepted a poisoned remote config without reporting FAILED or unhealthy")
}

func firstHealthyReport(reports []reportedReport) int {
	return slices.IndexFunc(reports, func(r reportedReport) bool {
		return r.Healthy != nil && *r.Healthy
	})
}

func distinctInstanceUIDs(reports []reportedReport) []string {
	var uids []string
	for _, report := range reports {
		if !slices.Contains(uids, report.InstanceUID) {
			uids = append(uids, report.InstanceUID)
		}
	}
	return uids
}

// assertRenderedSupervisorConfig checks the installer wrote the endpoint
// override and the OpAMP attributes into the host-side supervisor.yaml.
func assertRenderedSupervisorConfig(t *testing.T, endpoint string) {
	t.Helper()

	home, err := os.UserHomeDir()
	require.NoError(t, err)
	rendered, err := os.ReadFile(filepath.Join(home, ".coralogix-otel-collector", "supervisor.yaml"))
	require.NoError(t, err)

	lines := strings.Split(string(rendered), "\n")
	for _, expected := range []string{
		`  endpoint: "` + endpoint + `"`,
		`      service.name: "opentelemetry-collector"`,
		`      cx.agent.type: "docker"`,
		`      "fleet.test.id": "fleet-demo"`,
		`      "deployment.environment": "staging=blue"`,
	} {
		require.Containsf(t, lines, expected, "supervisor.yaml is missing line %q", expected)
	}
}

// assertContainerStaysUp asserts liveness via container state and restart
// count: `docker ps` also lists a restart-looping container.
func assertContainerStaysUp(t *testing.T) {
	t.Helper()

	for deadline := time.Now().Add(livenessWindow); time.Now().Before(deadline); time.Sleep(5 * time.Second) {
		require.Equal(t, "running", inspectContainer(containerName, "{{.State.Status}}"), "supervisor container is not running")
	}
	require.Equal(t, "0", inspectContainer(containerName, "{{.RestartCount}}"), "supervisor restarted during startup - config validation or runtime failure")
}

// reportedReport is the slice of an AgentToServer message the assertions care
// about. Healthy is nil when the message carried no health section.
type reportedReport struct {
	InstanceUID        string
	SequenceNum        uint64
	Healthy            *bool
	HealthStatus       string
	LastError          string
	Components         []string
	HasDescription     bool
	HasEffectiveConfig bool
	RemoteCfgStat      string
	RemoteCfgStatError string
	// SentAfterOfferDelivered marks reports the agent sent after it had
	// already received the remote config offer.
	SentAfterOfferDelivered bool
}

func (r reportedReport) String() string {
	healthy := "unset"
	if r.Healthy != nil {
		healthy = strconv.FormatBool(*r.Healthy)
	}
	return fmt.Sprintf(
		"uid=%s seq=%d healthy=%s status=%q last_error=%q components=%v description=%t effective_config=%t remote_config=%s %q after_offer=%t",
		r.InstanceUID, r.SequenceNum, healthy, r.HealthStatus, r.LastError, r.Components,
		r.HasDescription, r.HasEffectiveConfig, r.RemoteCfgStat, r.RemoteCfgStatError, r.SentAfterOfferDelivered,
	)
}

// opampRecorder is an in-process OpAMP server that records every
// AgentToServer report. Over plain HTTP opamp-go fires OnConnected and
// OnConnectionClose on every poll, so all state lives behind the mutex rather
// than in channels.
type opampRecorder struct {
	mu                sync.Mutex
	reports           []reportedReport
	sawBearerToken    bool
	sawWrongBearer    bool
	remoteConfigOffer *protobufs.AgentRemoteConfig
	offerDelivered    bool
}

func (r *opampRecorder) onConnecting(expectedBearer string) func(*http.Request) types.ConnectionResponse {
	return func(req *http.Request) types.ConnectionResponse {
		r.mu.Lock()
		// Record only whether the header matched; never the value itself.
		if req.Header.Get("Authorization") == expectedBearer {
			r.sawBearerToken = true
		} else {
			r.sawWrongBearer = true
		}
		r.mu.Unlock()

		return types.ConnectionResponse{
			Accept:              true,
			ConnectionCallbacks: types.ConnectionCallbacks{OnMessage: r.onMessage},
		}
	}
}

func (r *opampRecorder) onMessage(_ context.Context, _ types.Connection, msg *protobufs.AgentToServer) *protobufs.ServerToAgent {
	report := reportedReport{
		InstanceUID:        hex.EncodeToString(msg.GetInstanceUid()),
		SequenceNum:        msg.GetSequenceNum(),
		HasDescription:     msg.GetAgentDescription() != nil,
		HasEffectiveConfig: msg.GetEffectiveConfig() != nil,
	}
	if health := msg.GetHealth(); health != nil {
		report.Healthy = &health.Healthy
		report.HealthStatus = health.GetStatus()
		report.LastError = health.GetLastError()
		for component := range health.GetComponentHealthMap() {
			report.Components = append(report.Components, component)
		}
		slices.Sort(report.Components)
	}
	if status := msg.GetRemoteConfigStatus(); status != nil {
		report.RemoteCfgStat = status.GetStatus().String()
		report.RemoteCfgStatError = status.GetErrorMessage()
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	report.SentAfterOfferDelivered = r.offerDelivered
	r.reports = append(r.reports, report)

	// The return value IS the ServerToAgent response; nil keeps the liveness
	// flow free of any remote config offer.
	if r.remoteConfigOffer == nil {
		return nil
	}
	r.offerDelivered = true
	return &protobufs.ServerToAgent{
		InstanceUid:  msg.GetInstanceUid(),
		RemoteConfig: r.remoteConfigOffer,
		Capabilities: uint64(protobufs.ServerCapabilities_ServerCapabilities_AcceptsStatus |
			protobufs.ServerCapabilities_ServerCapabilities_OffersRemoteConfig |
			protobufs.ServerCapabilities_ServerCapabilities_AcceptsEffectiveConfig),
	}
}

func (r *opampRecorder) offerRemoteConfig(body []byte, hash []byte) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.remoteConfigOffer = &protobufs.AgentRemoteConfig{
		Config: &protobufs.AgentConfigMap{
			ConfigMap: map[string]*protobufs.AgentConfigObject{
				"": {Body: body, ContentType: "text/yaml"},
			},
		},
		ConfigHash: hash,
	}
}

func (r *opampRecorder) snapshot() []reportedReport {
	r.mu.Lock()
	defer r.mu.Unlock()
	return slices.Clone(r.reports)
}

func (r *opampRecorder) bearerTokenSeen() (matched, mismatched bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.sawBearerToken, r.sawWrongBearer
}

// startOpAMPServer serves the recorder on 0.0.0.0 so the supervisor container
// can reach it through the docker bridge gateway.
func startOpAMPServer(t *testing.T, expectedBearer string) *opampRecorder {
	t.Helper()

	recorder := &opampRecorder{}
	logger := zaptest.NewLogger(t, zaptest.Level(zap.InfoLevel)).Sugar()
	opamp := server.New(&opampLogger{logger})
	handler, connContext, err := opamp.Attach(server.Settings{
		Callbacks: types.Callbacks{OnConnecting: recorder.onConnecting(expectedBearer)},
	})
	require.NoError(t, err)

	mux := http.NewServeMux()
	mux.HandleFunc(opampPath, handler)
	listener, err := net.Listen("tcp", net.JoinHostPort("0.0.0.0", strconv.Itoa(opampPort)))
	require.NoError(t, err)
	httpServer := &http.Server{Handler: mux, ConnContext: connContext, ReadHeaderTimeout: 10 * time.Second}

	go func() {
		if err := httpServer.Serve(listener); err != nil && !errors.Is(err, http.ErrServerClosed) {
			t.Errorf("OpAMP server stopped: %v", err)
		}
	}()
	t.Cleanup(func() {
		if t.Failed() {
			for _, report := range recorder.snapshot() {
				t.Logf("OpAMP report: %s", report)
			}
		}
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = httpServer.Shutdown(ctx)
	})

	return recorder
}

// opampLogger adapts zap to opamp-go's printf-style logger interface.
type opampLogger struct {
	*zap.SugaredLogger
}

func (l *opampLogger) Debugf(_ context.Context, format string, v ...any) {
	l.SugaredLogger.Debugf(format, v...)
}

func (l *opampLogger) Errorf(_ context.Context, format string, v ...any) {
	l.SugaredLogger.Errorf(format, v...)
}

// repoRoot resolves the repository root from this module's directory
// (otel-installer/docker/e2e-test).
func repoRoot(t *testing.T) string {
	t.Helper()
	dir, err := os.Getwd()
	require.NoError(t, err)
	return filepath.Clean(filepath.Join(dir, "..", "..", ".."))
}

// coralogixEnv returns the domain and private key the installer runs with. The
// fake server never forwards anything, so CI's dummy values are fine.
func coralogixEnv() (domain, privateKey string) {
	domain = os.Getenv("CORALOGIX_DOMAIN")
	if domain == "" {
		domain = "us1.coralogix.com"
	}
	privateKey = os.Getenv("CORALOGIX_PRIVATE_KEY")
	if privateKey == "" {
		privateKey = "test-key-12345"
	}
	return domain, privateKey
}

// resolveHostEndpoint returns the address containers use to reach this test
// process: Docker Desktop's alias on macOS, the bridge gateway on Linux.
func resolveHostEndpoint(t *testing.T, root string) string {
	t.Helper()

	if runtime.GOOS == "darwin" {
		return "host.docker.internal"
	}

	gateway := strings.TrimSpace(runCmd(
		t,
		root,
		nil,
		"docker", "network", "inspect", "bridge",
		"--format", "{{range .IPAM.Config}}{{if .Gateway}}{{.Gateway}}{{end}}{{end}}",
	))
	require.NotEmpty(t, gateway, "failed to resolve docker bridge gateway")
	return gateway
}

// installSupervisor runs the Docker installer in Supervisor mode against the
// in-process OpAMP server and uninstalls it when the test ends, dumping the
// container logs first if the test failed.
func installSupervisor(t *testing.T, root, opampEndpoint string) {
	t.Helper()

	domain, privateKey := coralogixEnv()
	t.Cleanup(func() {
		if t.Failed() {
			t.Logf("container state: %s", inspectContainer(containerName, "State={{.State.Status}} ExitCode={{.State.ExitCode}} Restarts={{.RestartCount}}"))
			t.Logf("supervisor logs:\n%s", containerLogs(containerName))
		}
		cmd := exec.Command("bash", "./otel-installer/docker/docker-install.sh", "--uninstall")
		cmd.Dir = root
		if output, err := cmd.CombinedOutput(); err != nil {
			t.Logf("uninstall failed: %v\n%s", err, output)
		}
	})

	runCmd(
		t,
		root,
		[]string{"CORALOGIX_DOMAIN=" + domain, "CORALOGIX_PRIVATE_KEY=" + privateKey},
		"bash", "./otel-installer/docker/docker-install.sh", "-s",
		"--opamp-endpoint", opampEndpoint,
		"--opamp-attribute", "fleet.test.id=fleet-demo",
		"--opamp-attribute", "deployment.environment=staging=blue",
	)
}

// inspectContainer returns the formatted docker inspect output, or the error
// text when the container is gone.
func inspectContainer(name, format string) string {
	output, err := exec.Command("docker", "inspect", "-f", format, name).CombinedOutput()
	if err != nil {
		return fmt.Sprintf("docker inspect failed: %v: %s", err, output)
	}
	return strings.TrimSpace(string(output))
}

func containerLogs(name string) string {
	output, _ := exec.Command("docker", "logs", name).CombinedOutput()
	return string(output)
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
