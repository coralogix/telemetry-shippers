package e2e

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestE2E_FleetManager(t *testing.T) {
	t.Parallel()

	testServer, err := NewOpampTestServer()
	assert.NoError(t, err)
	err = testServer.Start("localhost:4320")
	assert.NoError(t, err)
	defer testServer.Stop()

	ctx := context.Background()
	ctxWithTimeout, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	// We wait for at least two messages:
	// 1st: reporting the creation of the agent.
	// 2nd: reporting the agent's initial configuration.
	// More messages might have arrived, but we don't care about the extra ones at the moment.
	testServer.AssertMessageCount(t, ctxWithTimeout, 2)
}
