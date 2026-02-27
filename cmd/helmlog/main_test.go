package main

import (
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
	todayDate := time.Now().UTC().Format("2006-01-02")

	input := "### v1.2.3 / " + todayDate + `
- [Fix] Prevent crash during startup
`

	_, err := parseMarkdown(strings.NewReader(input))
	if err != nil {
		t.Fatalf("parseMarkdown() error = %v", err)
	}
}
