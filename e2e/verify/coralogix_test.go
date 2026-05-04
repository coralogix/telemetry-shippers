package verify

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestQueryDataPrime_Success(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, http.MethodPost, r.Method)
		assert.Equal(t, "/api/v1/dataprime/query", r.URL.Path)
		assert.Equal(t, "test-key", r.Header.Get("Authorization")) // no Bearer prefix
		assert.Equal(t, "application/json", r.Header.Get("Content-Type"))

		body, _ := io.ReadAll(r.Body)
		var req map[string]interface{}
		require.NoError(t, json.Unmarshal(body, &req))
		assert.Contains(t, req["query"], "source logs")

		w.Header().Set("Content-Type", "application/x-ndjson")
		// Two NDJSON objects: one with results, one without
		_, _ = w.Write([]byte(`{"queryId":{"queryId":"abc"}}` + "\n"))
		_, _ = w.Write([]byte(`{"result":{"results":[{"metadata":[]}, {"metadata":[]}]}}` + "\n"))
	}))
	defer srv.Close()

	c := newTestClient(srv)
	res, err := c.QueryDataPrime(context.Background(), "source logs | limit 5", time.Now().Add(-1*time.Hour))
	require.NoError(t, err)
	assert.Equal(t, 2, res.Count)
	assert.NotEmpty(t, res.Sample)
}

func TestQueryDataPrime_NoResults(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"result":{"results":[]}}`))
	}))
	defer srv.Close()

	c := newTestClient(srv)
	res, err := c.QueryDataPrime(context.Background(), "source logs | limit 5", time.Now())
	require.NoError(t, err)
	assert.Equal(t, 0, res.Count)
	assert.Empty(t, res.Sample)
}

func TestQueryDataPrime_HTTPError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"error":"unauthorized"}`))
	}))
	defer srv.Close()

	c := newTestClient(srv)
	_, err := c.QueryDataPrime(context.Background(), "x", time.Now())
	require.Error(t, err)
	assert.Contains(t, err.Error(), "401")
}

func TestQueryPromQL_Success(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, http.MethodGet, r.Method)
		assert.Equal(t, "/metrics/api/v1/query", r.URL.Path)
		assert.Equal(t, "Bearer test-key", r.Header.Get("Authorization")) // Bearer prefix for metrics
		assert.NotEmpty(t, r.URL.Query().Get("query"))

		_, _ = w.Write([]byte(`{
			"status":"success",
			"data":{
				"resultType":"vector",
				"result":[
					{"metric":{"__name__":"x","e2e_run_id":"abc"},"value":[1,"1"]},
					{"metric":{"__name__":"y","e2e_run_id":"abc"},"value":[2,"2"]}
				]
			}
		}`))
	}))
	defer srv.Close()

	c := newTestClient(srv)
	res, err := c.QueryPromQL(context.Background(), `{e2e_run_id="abc"}`)
	require.NoError(t, err)
	assert.Equal(t, 2, res.Count)
	assert.Contains(t, res.Sample, "__name__")
}

func TestQueryPromQL_PromError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"status":"error","errorType":"bad_data","error":"parse error"}`))
	}))
	defer srv.Close()

	c := newTestClient(srv)
	_, err := c.QueryPromQL(context.Background(), "{")
	require.Error(t, err)
	assert.Contains(t, err.Error(), "parse error")
}

// newTestClient builds a Client whose base URL points at the test server.
// We do this by replacing "ng-api-http.<domain>" with the test server host.
func newTestClient(srv *httptest.Server) *Client {
	c := NewClient("coralogix.com", "test-key")
	// Wrap the HTTP client to rewrite the URL host to the test server.
	c.HTTPClient = &http.Client{
		Transport: rewriteTransport{
			to:    srv.URL,
			inner: http.DefaultTransport,
		},
	}
	return c
}

// rewriteTransport rewrites every outgoing request's URL to point at `to`,
// preserving the path + query.
type rewriteTransport struct {
	to    string
	inner http.RoundTripper
}

func (rt rewriteTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	// Replace scheme + host with the test server's
	original := req.URL.String()
	rewritten := strings.Replace(original, "https://ng-api-http.coralogix.com", rt.to, 1)
	newReq := req.Clone(req.Context())
	u, err := newReq.URL.Parse(rewritten)
	if err != nil {
		return nil, err
	}
	newReq.URL = u
	newReq.Host = ""
	return rt.inner.RoundTrip(newReq)
}
