package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/coralogix/telemetry-shippers/pkg/helmlog"
)

func TestParseMarkdownSuccess(t *testing.T) {
	input := `# Changelog

### v1.2.3 / 2026-02-10
- [Chore] Bump chart dependency to opentelemetry-collector 0.129.2
#### Changes from opentelemetry-collector 0.129.2
- [Fix] Keep this line

### v1.2.2 / 2026-01-01
- [Feat] Add deterministic parser
`

	result, err := parseMarkdown(strings.NewReader(input))
	if err != nil {
		t.Fatalf("parseMarkdown() error = %v", err)
	}

	if result.ReleaseCount != 2 {
		t.Fatalf("ReleaseCount = %d, want 2", result.ReleaseCount)
	}

	if result.EntryCount != 2 {
		t.Fatalf("EntryCount = %d, want 2", result.EntryCount)
	}

	if got := result.Log.Releases[0].Entries[0].Tag; got != "Fix" {
		t.Fatalf("first tag = %q, want %q", got, "Fix")
	}
}

func TestParseMarkdownUnknownTag(t *testing.T) {
	input := `### v1.2.3 / 2026-02-10
- [Improvement] Reduce memory usage
`

	_, err := parseMarkdown(strings.NewReader(input))
	if err == nil {
		t.Fatal("expected parse error, got nil")
	}

	msg := err.Error()
	if !strings.Contains(msg, `unknown tag "[Improvement]"`) {
		t.Fatalf("error = %q, expected unknown tag", msg)
	}
	if !strings.Contains(msg, "v1.2.3") {
		t.Fatalf("error = %q, expected release context", msg)
	}
}

func TestParseMarkdownEntryWithWarningPrefixTag(t *testing.T) {
	input := `### v1.2.3 / 2026-02-10
- [:warning: Change][Feat] Keep compatibility while upgrading dependency
`

	result, err := parseMarkdown(strings.NewReader(input))
	if err != nil {
		t.Fatalf("parseMarkdown() error = %v", err)
	}

	if result.EntryCount != 1 {
		t.Fatalf("EntryCount = %d, want 1", result.EntryCount)
	}

	if got := result.Log.Releases[0].Entries[0].Tag; got != "Feat" {
		t.Fatalf("tag = %q, want %q", got, "Feat")
	}
}

func TestParseMarkdownInvalidReleaseHeader(t *testing.T) {
	input := `### v1.2 / 2026-02-10
- [Fix] invalid release before this line
`

	_, err := parseMarkdown(strings.NewReader(input))
	if err == nil {
		t.Fatal("expected parse error, got nil")
	}

	if !strings.Contains(err.Error(), `release header must match "### vX.Y.Z / YYYY-MM-DD"`) {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestSortReleasesNewestFirst(t *testing.T) {
	releases := []helmlog.Release{
		{Version: "v1.1.0", Date: "2025-01-10"},
		{Version: "v1.2.0", Date: "2026-01-01"},
		{Version: "v1.3.0", Date: "2026-01-01"},
	}

	sortReleasesNewestFirst(releases)

	if releases[0].Version != "v1.3.0" {
		t.Fatalf("first release = %q, want v1.3.0", releases[0].Version)
	}
	if releases[1].Version != "v1.2.0" {
		t.Fatalf("second release = %q, want v1.2.0", releases[1].Version)
	}
	if releases[2].Version != "v1.1.0" {
		t.Fatalf("third release = %q, want v1.1.0", releases[2].Version)
	}
}

func TestParseMarkdownSupportsSublevelEntries(t *testing.T) {
	input := `### v1.2.3 / 2026-02-10
- [Feat] Add IIS logs collection with W3C format parsing
  - Header metadata parsing for dynamic field detection
  - CSV parsing with automatic header detection
`

	result, err := parseMarkdown(strings.NewReader(input))
	if err != nil {
		t.Fatalf("parseMarkdown() error = %v", err)
	}

	if result.EntryCount != 1 {
		t.Fatalf("EntryCount = %d, want 1", result.EntryCount)
	}

	got := result.Log.Releases[0].Entries[0].Text
	want := "Add IIS logs collection with W3C format parsing\n- Header metadata parsing for dynamic field detection\n- CSV parsing with automatic header detection"
	if got != want {
		t.Fatalf("entry text = %q, want %q", got, want)
	}
}

func TestParseMarkdownSublevelEntryWithoutParentFails(t *testing.T) {
	input := `### v1.2.3 / 2026-02-10
  - Header metadata parsing for dynamic field detection
`

	_, err := parseMarkdown(strings.NewReader(input))
	if err == nil {
		t.Fatal("expected parse error, got nil")
	}

	if !strings.Contains(err.Error(), "sublevel entry must follow a top-level tagged entry") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestParseMarkdownFutureReleaseDateFails(t *testing.T) {
	futureDate := time.Now().UTC().Add(24 * time.Hour).Format("2006-01-02")

	input := "### v1.2.3 / " + futureDate + `
- [Fix] Prevent crash during startup
`

	_, err := parseMarkdown(strings.NewReader(input))
	if err == nil {
		t.Fatal("expected parse error, got nil")
	}

	if !strings.Contains(err.Error(), "release date must not be in the future") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestParseMarkdownCurrentReleaseDatePasses(t *testing.T) {
	todayDate := time.Now().In(time.Local).Format("2006-01-02")

	input := "### v1.2.3 / " + todayDate + `
- [Fix] Prevent crash during startup
`

	_, err := parseMarkdown(strings.NewReader(input))
	if err != nil {
		t.Fatalf("parseMarkdown() error = %v", err)
	}
}

func TestValidateReleaseDateUsesLocalCalendarDay(t *testing.T) {
	originalNowFunc := nowFunc
	originalLocal := time.Local
	t.Cleanup(func() {
		nowFunc = originalNowFunc
		time.Local = originalLocal
	})

	localZone := time.FixedZone("UTC+2", 2*60*60)
	time.Local = localZone
	nowFunc = func() time.Time {
		return time.Date(2026, 2, 10, 0, 30, 0, 0, localZone)
	}

	if err := validateReleaseDate("2026-02-10"); err != nil {
		t.Fatalf("validateReleaseDate() error = %v, want nil", err)
	}

	err := validateReleaseDate("2026-02-11")
	if err == nil {
		t.Fatal("expected future-date error, got nil")
	}
	if !strings.Contains(err.Error(), "release date must not be in the future") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestNormalizeOS(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    string
		wantErr bool
	}{
		{name: "default linux", input: "", want: "linux"},
		{name: "linux", input: "linux", want: "linux"},
		{name: "mac alias", input: "mac", want: "macos"},
		{name: "darwin alias", input: "darwin", want: "macos"},
		{name: "windows alias", input: "win", want: "windows"},
		{name: "unsupported", input: "solaris", wantErr: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := normalizeOS(tt.input)
			if tt.wantErr {
				if err == nil {
					t.Fatalf("normalizeOS(%q) error = nil, want error", tt.input)
				}
				return
			}

			if err != nil {
				t.Fatalf("normalizeOS(%q) error = %v", tt.input, err)
			}

			if got != tt.want {
				t.Fatalf("normalizeOS(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

func TestExtractVersionsFromChart(t *testing.T) {
	chart := `apiVersion: v2
name: linux-standalone
description: Standalone Linux OpenTelemetry Collector configuration
version: 0.0.18
dependencies:
  - name: opentelemetry-collector
    alias: opentelemetry-agent
    version: "0.130.4"
    repository: https://cgx.jfrog.io/artifactory/coralogix-charts-virtual
`

	chartVersion, collectorVersion := extractVersionsFromChart(chart)
	if chartVersion != "0.0.18" {
		t.Fatalf("chartVersion = %q, want %q", chartVersion, "0.0.18")
	}
	if collectorVersion != "0.130.4" {
		t.Fatalf("collectorVersion = %q, want %q", collectorVersion, "0.130.4")
	}
}

func TestExtractVersionsFromChartQuotedChartVersion(t *testing.T) {
	chart := `apiVersion: v2
name: linux-standalone
description: Standalone Linux OpenTelemetry Collector configuration
version: "0.0.18"
dependencies:
  - name: opentelemetry-collector
    alias: opentelemetry-agent
    version: "0.130.4"
    repository: https://cgx.jfrog.io/artifactory/coralogix-charts-virtual
`

	chartVersion, collectorVersion := extractVersionsFromChart(chart)
	if chartVersion != "0.0.18" {
		t.Fatalf("chartVersion = %q, want %q", chartVersion, "0.0.18")
	}
	if collectorVersion != "0.130.4" {
		t.Fatalf("collectorVersion = %q, want %q", collectorVersion, "0.130.4")
	}
}

func TestExtractVersionsFromChartMissingDependency(t *testing.T) {
	chart := `apiVersion: v2
name: linux-standalone
version: 0.0.18
dependencies:
  - name: another-dependency
    version: "1.2.3"
`

	chartVersion, collectorVersion := extractVersionsFromChart(chart)
	if chartVersion != "0.0.18" {
		t.Fatalf("chartVersion = %q, want %q", chartVersion, "0.0.18")
	}
	if collectorVersion != "" {
		t.Fatalf("collectorVersion = %q, want empty", collectorVersion)
	}
}

func TestMarshalOSMappingJSON(t *testing.T) {
	mapping := osMappingResult{
		Mappings: []osMappingEntry{
			{ChartVersion: "0.0.18", CollectorChartVersion: "0.130.4"},
			{ChartVersion: "0.0.17", CollectorChartVersion: "0.129.2"},
		},
	}

	output, err := marshalOSMappingJSON(mapping)
	if err != nil {
		t.Fatalf("marshalOSMappingJSON() error = %v", err)
	}

	var got osMappingResult
	if err := json.Unmarshal(output, &got); err != nil {
		t.Fatalf("json.Unmarshal() error = %v", err)
	}

	if !reflect.DeepEqual(got, mapping) {
		t.Fatalf("decoded output = %#v, want %#v", got, mapping)
	}

	if !strings.HasSuffix(string(output), "\n") {
		t.Fatalf("output should end with newline, got %q", string(output))
	}
}

func TestBuildOSMappingLimitsHistoryToTargetRef(t *testing.T) {
	repoRoot := setupOSMappingTestRepo(t)

	mainResult, err := buildOSMapping(repoRoot, filepath.Join("otel-linux-standalone", "Chart.yaml"), "HEAD")
	if err != nil {
		t.Fatalf("buildOSMapping(HEAD) error = %v", err)
	}

	wantMain := []osMappingEntry{
		{ChartVersion: "0.0.2", CollectorChartVersion: "0.101.0"},
		{ChartVersion: "0.0.1", CollectorChartVersion: "0.100.0"},
	}
	if !reflect.DeepEqual(mainResult.Mappings, wantMain) {
		t.Fatalf("HEAD mappings = %#v, want %#v", mainResult.Mappings, wantMain)
	}
}

func TestBuildOSMappingSupportsExplicitRef(t *testing.T) {
	repoRoot := setupOSMappingTestRepo(t)

	featureResult, err := buildOSMapping(repoRoot, filepath.Join("otel-linux-standalone", "Chart.yaml"), "feature")
	if err != nil {
		t.Fatalf("buildOSMapping(feature) error = %v", err)
	}

	wantFeature := []osMappingEntry{
		{ChartVersion: "0.9.9", CollectorChartVersion: "9.9.9"},
		{ChartVersion: "0.0.1", CollectorChartVersion: "0.100.0"},
	}
	if !reflect.DeepEqual(featureResult.Mappings, wantFeature) {
		t.Fatalf("feature mappings = %#v, want %#v", featureResult.Mappings, wantFeature)
	}
}

func TestBuildOSMappingKeepsNewestDuplicateChartVersion(t *testing.T) {
	repoRoot := setupOSMappingTestRepo(t)

	writeTestChart(t, repoRoot, "0.0.2", "0.099.0")
	runTestGit(t, repoRoot, "commit", "-am", "main rollback collector for same chart version")

	result, err := buildOSMapping(repoRoot, filepath.Join("otel-linux-standalone", "Chart.yaml"), "HEAD")
	if err != nil {
		t.Fatalf("buildOSMapping(HEAD) error = %v", err)
	}

	want := []osMappingEntry{
		{ChartVersion: "0.0.2", CollectorChartVersion: "0.099.0"},
		{ChartVersion: "0.0.1", CollectorChartVersion: "0.100.0"},
	}
	if !reflect.DeepEqual(result.Mappings, want) {
		t.Fatalf("HEAD mappings after duplicate chart version = %#v, want %#v", result.Mappings, want)
	}
}

func setupOSMappingTestRepo(t *testing.T) string {
	t.Helper()

	repoRoot, err := os.MkdirTemp(".", "os-mapping-test-")
	if err != nil {
		t.Fatalf("os.MkdirTemp() error = %v", err)
	}
	repoRoot, err = filepath.Abs(repoRoot)
	if err != nil {
		t.Fatalf("filepath.Abs() error = %v", err)
	}
	t.Cleanup(func() {
		if removeErr := os.RemoveAll(repoRoot); removeErr != nil {
			t.Fatalf("os.RemoveAll() error = %v", removeErr)
		}
	})

	runTestGit(t, repoRoot, "init", "-b", "main")

	writeTestChart(t, repoRoot, "0.0.1", "0.100.0")
	runTestGit(t, repoRoot, "add", "otel-linux-standalone/Chart.yaml")
	runTestGit(t, repoRoot, "commit", "-m", "main base")

	runTestGit(t, repoRoot, "checkout", "-b", "feature")
	writeTestChart(t, repoRoot, "0.9.9", "9.9.9")
	runTestGit(t, repoRoot, "commit", "-am", "feature only")

	runTestGit(t, repoRoot, "checkout", "main")
	writeTestChart(t, repoRoot, "0.0.2", "0.101.0")
	runTestGit(t, repoRoot, "commit", "-am", "main update")

	return repoRoot
}

func writeTestChart(t *testing.T, repoRoot, chartVersion, collectorVersion string) {
	t.Helper()

	chartPath := filepath.Join(repoRoot, "otel-linux-standalone", "Chart.yaml")
	if err := os.MkdirAll(filepath.Dir(chartPath), 0o755); err != nil {
		t.Fatalf("os.MkdirAll() error = %v", err)
	}

	content := `apiVersion: v2
name: linux-standalone
version: ` + chartVersion + `
dependencies:
  - name: opentelemetry-collector
    version: "` + collectorVersion + `"
`
	if err := os.WriteFile(chartPath, []byte(content), 0o644); err != nil {
		t.Fatalf("os.WriteFile() error = %v", err)
	}
}

func runTestGit(t *testing.T, repoRoot string, args ...string) string {
	t.Helper()

	if len(args) > 0 && args[0] == "init" {
		templateDir := filepath.Join(repoRoot, ".git-template")
		if err := os.MkdirAll(templateDir, 0o755); err != nil {
			t.Fatalf("os.MkdirAll() error = %v", err)
		}
		args = append([]string{"init", "--template", templateDir}, args[1:]...)
	}

	cmd := exec.Command("git", args...)
	cmd.Dir = repoRoot
	cmd.Env = append(os.Environ(),
		"GIT_AUTHOR_NAME=Test User",
		"GIT_AUTHOR_EMAIL=test@example.com",
		"GIT_COMMITTER_NAME=Test User",
		"GIT_COMMITTER_EMAIL=test@example.com",
	)

	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %s failed: %v\n%s", strings.Join(args, " "), err, string(output))
	}

	return string(output)
}
