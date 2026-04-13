// Package verify provides functions to verify that telemetry data has arrived
// in Coralogix after an E2E test deploys an OTel collector.
package verify

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"
)

// Client wraps HTTP calls to the Coralogix DataPrime and PromQL APIs.
type Client struct {
	Domain     string // e.g. "coralogix.com"
	APIKey     string // Coralogix Logs Query Key
	HTTPClient *http.Client
}

// NewClient returns a Client with a sensible default HTTP timeout.
func NewClient(domain, apiKey string) *Client {
	return &Client{
		Domain:     domain,
		APIKey:     apiKey,
		HTTPClient: &http.Client{Timeout: 30 * time.Second},
	}
}

// dataprimeRequest is the body for POST /api/v1/dataprime/query.
type dataprimeRequest struct {
	Query    string             `json:"query"`
	Metadata dataprimeMetadata  `json:"metadata"`
}

type dataprimeMetadata struct {
	StartDate string `json:"startDate"`
	EndDate   string `json:"endDate"`
}

// DataPrimeResult is a partial decode of the DataPrime response. The API
// returns a stream of newline-delimited JSON objects; we count "result" entries
// and capture the rows for downstream attribute inspection.
type DataPrimeResult struct {
	Count  int            // number of result rows returned
	Rows   []DataPrimeRow // parsed rows (resource attributes accessible via Rows[i].ResourceAttributes())
	Sample string         // first result row as a JSON string (for debugging)
	Raw    string         // full raw response (for debugging on error)
}

// DataPrimeRow is one row from a DataPrime query.
type DataPrimeRow struct {
	Metadata []KV   `json:"metadata"`
	Labels   []KV   `json:"labels"`
	UserData string `json:"userData"` // JSON-encoded string, parse separately
}

// KV is a single metadata/label entry.
type KV struct {
	Key   string `json:"key"`
	Value string `json:"value"`
}

// ResourceAttributes parses the userData JSON and returns the
// resource.attributes map, or nil if the row has no parseable resource section.
func (r DataPrimeRow) ResourceAttributes() map[string]interface{} {
	if r.UserData == "" {
		return nil
	}
	var doc struct {
		Resource struct {
			Attributes map[string]interface{} `json:"attributes"`
		} `json:"resource"`
	}
	if err := json.Unmarshal([]byte(r.UserData), &doc); err != nil {
		return nil
	}
	return doc.Resource.Attributes
}

// QueryDataPrime executes a DataPrime query against logs or spans.
// The query string uses DataPrime syntax, e.g.:
//
//	source logs | filter $d.resource.attributes.e2e_run_id == 'abc' | limit 5
func (c *Client) QueryDataPrime(ctx context.Context, query string, since time.Time) (*DataPrimeResult, error) {
	endpoint := fmt.Sprintf("https://ng-api-http.%s/api/v1/dataprime/query", c.Domain)

	body, err := json.Marshal(dataprimeRequest{
		Query: query,
		Metadata: dataprimeMetadata{
			StartDate: since.UTC().Format("2006-01-02T15:04:05.00Z"),
			EndDate:   time.Now().UTC().Format("2006-01-02T15:04:05.00Z"),
		},
	})
	if err != nil {
		return nil, fmt.Errorf("marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", c.APIKey) // DataPrime: no "Bearer" prefix

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("http: %w", err)
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("dataprime returned %d: %s", resp.StatusCode, string(raw))
	}

	return parseDataPrime(string(raw)), nil
}

// parseDataPrime parses the NDJSON response. DataPrime returns a stream of
// JSON objects, one per line. Each object has a "result" key with rows, or
// "queryId"/"warning"/"error" keys. We count rows across all "result" objects
// and parse each into DataPrimeRow.
func parseDataPrime(body string) *DataPrimeResult {
	res := &DataPrimeResult{Raw: body}

	dec := json.NewDecoder(bytes.NewReader([]byte(body)))
	for dec.More() {
		var obj struct {
			Result *struct {
				Results []json.RawMessage `json:"results"`
			} `json:"result"`
		}
		if err := dec.Decode(&obj); err != nil {
			break
		}
		if obj.Result == nil {
			continue
		}
		for _, raw := range obj.Result.Results {
			if res.Sample == "" {
				res.Sample = string(raw)
			}
			var row DataPrimeRow
			if err := json.Unmarshal(raw, &row); err == nil {
				res.Rows = append(res.Rows, row)
			}
			res.Count++
		}
	}
	return res
}

// PromQLResult is a partial decode of the PromQL query response.
type PromQLResult struct {
	Count  int           // number of series returned
	Series []PromQLSeries // parsed series with labels accessible
	Sample string         // first series as a JSON string
	Raw    string
}

// PromQLSeries is one series from a PromQL response. We only care about the
// metric labels for verification (not the value).
type PromQLSeries struct {
	Metric map[string]string `json:"metric"`
	Value  []interface{}     `json:"value,omitempty"` // [timestamp, "value"]
}

// MetricValue returns the numeric value of an instant query result, or 0 if
// the response shape is unexpected. Used by collector_health checks.
func (s PromQLSeries) MetricValue() float64 {
	if len(s.Value) < 2 {
		return 0
	}
	str, ok := s.Value[1].(string)
	if !ok {
		return 0
	}
	var f float64
	fmt.Sscanf(str, "%f", &f)
	return f
}

// promQLResponse matches Coralogix's PromQL response shape:
//
//	{"status":"success","data":{"resultType":"vector","result":[...]}}
type promQLResponse struct {
	Status string `json:"status"`
	Data   struct {
		ResultType string            `json:"resultType"`
		Result     []json.RawMessage `json:"result"`
	} `json:"data"`
	ErrorType string `json:"errorType,omitempty"`
	Error     string `json:"error,omitempty"`
}

// QueryPromQL executes an instant PromQL query, e.g. `{e2e_run_id="abc"}`.
// The endpoint is /metrics/api/v1/query (instant query at current time).
func (c *Client) QueryPromQL(ctx context.Context, query string) (*PromQLResult, error) {
	endpoint := fmt.Sprintf("https://ng-api-http.%s/metrics/api/v1/query", c.Domain)

	q := url.Values{}
	q.Set("query", query)
	q.Set("time", fmt.Sprintf("%d", time.Now().Unix()))

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint+"?"+q.Encode(), nil)
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}
	// Metrics API uses Bearer prefix (different from DataPrime)
	req.Header.Set("Authorization", "Bearer "+c.APIKey)

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("http: %w", err)
	}
	defer resp.Body.Close()

	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("promql returned %d: %s", resp.StatusCode, string(raw))
	}

	var parsed promQLResponse
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return nil, fmt.Errorf("decode response: %w (body: %s)", err, string(raw))
	}
	if parsed.Status != "success" {
		return nil, fmt.Errorf("promql error: %s: %s", parsed.ErrorType, parsed.Error)
	}

	res := &PromQLResult{Raw: string(raw), Count: len(parsed.Data.Result)}
	if len(parsed.Data.Result) > 0 {
		res.Sample = string(parsed.Data.Result[0])
	}
	for _, raw := range parsed.Data.Result {
		var s PromQLSeries
		if err := json.Unmarshal(raw, &s); err == nil {
			res.Series = append(res.Series, s)
		}
	}
	return res, nil
}
