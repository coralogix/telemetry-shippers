package opampserver

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"sync"
	"testing"
	"time"

	"github.com/open-telemetry/opamp-go/protobufs"
	"github.com/open-telemetry/opamp-go/server"
	"github.com/open-telemetry/opamp-go/server/types"
	"github.com/stretchr/testify/assert"
	"go.uber.org/zap"
)

type Server struct {
	logger   *logWrapper
	opampSrv server.OpAMPServer

	messageMu sync.Mutex
	messages  []*protobufs.AgentToServer
}

func New() (*Server, error) {
	zapLogger, err := zap.NewDevelopment()
	if err != nil {
		return nil, err
	}
	opampLogger := newOpAMPLogger(zapLogger)
	return &Server{
		opampSrv: server.New(opampLogger),
		logger:   opampLogger,
	}, nil
}

func StartTestServer(t *testing.T, listenAddr string) *Server {
	t.Helper()

	testServer, err := New()
	if err != nil {
		t.Fatalf("failed to create OpAMP test server: %v", err)
	}

	if err := testServer.Start(listenAddr); err != nil {
		t.Fatalf("failed to start OpAMP test server: %v", err)
	}

	t.Cleanup(func() {
		_ = testServer.Stop()
	})
	return testServer
}

func StartTestServerOnFreePort(t *testing.T, host string) (*Server, int) {
	t.Helper()

	testServer := StartTestServer(t, fmt.Sprintf("%s:0", host))
	addr := testServer.Addr()
	tcpAddr, ok := addr.(*net.TCPAddr)
	if !ok || tcpAddr == nil || tcpAddr.Port == 0 {
		t.Fatalf("failed to resolve OpAMP server port from addr %v", addr)
	}
	return testServer, tcpAddr.Port
}

func (s *Server) Start(listenAddr string) error {
	settings := server.StartSettings{
		ListenEndpoint: listenAddr,
		Settings: server.Settings{
			Callbacks: types.Callbacks{
				OnConnecting: s.handleConnect,
			},
		},
	}
	return s.opampSrv.Start(settings)
}

func (s *Server) Stop() error {
	return s.opampSrv.Stop(context.TODO())
}

func (s *Server) Addr() net.Addr {
	return s.opampSrv.Addr()
}

func (s *Server) AssertMessageCount(t *testing.T, ctx context.Context, count int) {
	assert.Eventually(t, func() bool {
		s.messageMu.Lock()
		defer s.messageMu.Unlock()
		return len(s.messages) >= count
	}, 1*time.Minute, 1*time.Second, "timeout waiting for %d messages", count)
}

func (s *Server) MessagesSnapshot() []*protobufs.AgentToServer {
	s.messageMu.Lock()
	defer s.messageMu.Unlock()

	if len(s.messages) == 0 {
		return nil
	}

	snapshot := make([]*protobufs.AgentToServer, len(s.messages))
	copy(snapshot, s.messages)
	return snapshot
}

func (s *Server) handleConnect(_ *http.Request) types.ConnectionResponse {
	return types.ConnectionResponse{
		Accept:         true,
		HTTPStatusCode: http.StatusOK,
		ConnectionCallbacks: types.ConnectionCallbacks{
			OnMessage: s.handleMessage,
		},
	}
}

func (s *Server) handleMessage(
	ctx context.Context,
	_ types.Connection,
	msg *protobufs.AgentToServer,
) *protobufs.ServerToAgent {
	s.logger.Debugf(ctx, "Received message: %s", msg.String())
	s.messageMu.Lock()
	defer s.messageMu.Unlock()
	s.messages = append(s.messages, msg)
	return &protobufs.ServerToAgent{}
}

type logWrapper struct {
	logger *zap.Logger
}

func newOpAMPLogger(l *zap.Logger) *logWrapper {
	return &logWrapper{
		logger: l.With(zap.String("component", "opamp-server")),
	}
}

func (l *logWrapper) Debugf(ctx context.Context, format string, v ...any) {
	l.logger.Debug(fmt.Sprintf(format, v...))
}

func (l *logWrapper) Errorf(ctx context.Context, format string, v ...any) {
	l.logger.Error(fmt.Sprintf(format, v...))
}
