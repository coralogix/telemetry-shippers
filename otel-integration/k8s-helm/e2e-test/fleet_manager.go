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
	"go.uber.org/zap"
)

type TestOpampServer struct {
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

func NewOpampTestServer() (*TestOpampServer, error) {
	zapLogger, err := zap.NewDevelopment()
	if err != nil {
		return nil, err
	}
	opampLogger := newOpAMPLogger(zapLogger)
	return &TestOpampServer{
		opampSrv:    server.New(opampLogger),
		logger:      opampLogger,
		messageLock: &sync.Mutex{},
	}, nil
}

func (s *TestOpampServer) Start(listenAddr string) error {
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

func (s *TestOpampServer) Stop() error {
	return s.opampSrv.Stop(context.TODO())
}

func (s *TestOpampServer) handleConnect(requset *http.Request) types.ConnectionResponse {
	return types.ConnectionResponse{
		Accept:         true,
		HTTPStatusCode: http.StatusOK,
		ConnectionCallbacks: types.ConnectionCallbacks{
			OnMessage: s.handleMessage,
		},
	}
}

func (s *TestOpampServer) handleMessage(
	ctx context.Context,
	conn types.Connection,
	msg *protobufs.AgentToServer,
) *protobufs.ServerToAgent {
	s.logger.Debugf(ctx, "Received message: %v", msg)
	s.messageLock.Lock()
	defer s.messageLock.Unlock()
	s.Messages = append(s.Messages, msg)
	return &protobufs.ServerToAgent{}
}

func (s *TestOpampServer) AssertMessageCount(t *testing.T, ctx context.Context, count int) {
	gotCount := make(chan struct{})
	defer close(gotCount)
	go func() {
		for {
			s.messageLock.Lock()
			msgCount := len(s.Messages)
			s.messageLock.Unlock()
			if msgCount >= count {
				gotCount <- struct{}{}
				return
			}
			time.Sleep(1 * time.Second)
		}
	}()

	select {
	case <-ctx.Done():
		t.Fatal("timeout waiting for messages")
	case <-gotCount:
		return
	}
}
