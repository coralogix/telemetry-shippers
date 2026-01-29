package testhelpers

import (
	"net"
	"os"
	"testing"

	"github.com/stretchr/testify/require"
)

func HostEndpoint(t *testing.T) string {
	t.Helper()

	host := os.Getenv("HOSTENDPOINT")
	require.NotEmpty(t, host, "HOSTENDPOINT must be set")
	return host
}

func GetFreePort(t *testing.T) int {
	t.Helper()

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	defer listener.Close()
	return listener.Addr().(*net.TCPAddr).Port
}
