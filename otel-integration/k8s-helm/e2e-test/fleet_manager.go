package e2e

import (
	"context"
	"fmt"
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

type testOpampServer struct {
	logger      *logWrapper
	opampSrv    server.OpAMPServer
	messageLock *sync.Mutex
	Messages    []*protobufs.AgentToServer
}

func newOpAMPLogger(l *zap.Logger) *logWrapper {
	return &logWrapper{
		logger: l.With(zap.String("component", "opamp-server")),
	}
}

type logWrapper struct {
	logger *zap.Logger
}

func (l *logWrapper) Debugf(ctx context.Context, format string, v ...any) {
	l.logger.Debug(fmt.Sprintf(format, v...))
}

func (l *logWrapper) Errorf(ctx context.Context, format string, v ...any) {
	l.logger.Error(fmt.Sprintf(format, v...))
}

func newOpampTestServer() (*testOpampServer, error) {
	zapLogger, err := zap.NewDevelopment()
	if err != nil {
		return nil, err
	}
	opampLogger := newOpAMPLogger(zapLogger)
	return &testOpampServer{
		opampSrv:    server.New(opampLogger),
		logger:      opampLogger,
		messageLock: &sync.Mutex{},
	}, nil
}

func (s *testOpampServer) start(listenAddr string) error {
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

func (s *testOpampServer) stop() error {
	return s.opampSrv.Stop(context.TODO())
}

func (s *testOpampServer) handleConnect(requset *http.Request) types.ConnectionResponse {
	return types.ConnectionResponse{
		Accept:         true,
		HTTPStatusCode: http.StatusOK,
		ConnectionCallbacks: types.ConnectionCallbacks{
			OnMessage: s.handleMessage,
		},
	}
}

func (s *testOpampServer) handleMessage(
	ctx context.Context,
	conn types.Connection,
	msg *protobufs.AgentToServer,
) *protobufs.ServerToAgent {
	s.logger.Debugf(ctx, "Received message: %s", msg.String())
	s.messageLock.Lock()
	defer s.messageLock.Unlock()
	s.Messages = append(s.Messages, msg)
	return &protobufs.ServerToAgent{}
}

func (s *testOpampServer) assertMessageCount(t *testing.T, ctx context.Context, count int) {
	assert.Eventually(t, func() bool {
		s.messageLock.Lock()
		defer s.messageLock.Unlock()
		return len(s.Messages) >= count
	}, 1*time.Minute, 1*time.Second, "timeout waiting for 2 messages")
}
