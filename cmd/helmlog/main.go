package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/coralogix/telemetry-shippers/pkg/helmlog"
	"github.com/spf13/cobra"
)

var (
	releaseHeaderPattern = regexp.MustCompile(`^### (v\d+\.\d+\.\d+) / (\d{4}-\d{2}-\d{2})$`)
)

var allowedTags = map[string]bool{
	"feat":                      true,
	"feature":                   true,
	"fix":                       true,
	"bug":                       true,
	"change":                    true,
	"breaking":                  true,
	"chore":                     true,
	"revert":                    true,
	"update":                    true,
	"docs":                      true,
	":warning: change":          true,
	":warning: breaking change": true,
}

const droppedEntryPhrase = "Bump chart dependency to opentelemetry-collector"

type parseResult struct {
	Log          helmlog.Changelog
	ReleaseCount int
	EntryCount   int
}

type parseError struct {
	ReleaseVersion string
	ReleaseDate    string
	Reason         string
	Line           string
}

func (e parseError) Error() string {
	if e.ReleaseVersion == "" {
		return fmt.Sprintf("ERROR: invalid changelog entry\nReason: %s\nLine: %s", e.Reason, e.Line)
	}

	return fmt.Sprintf("ERROR: invalid entry at release %s (%s)\nReason: %s\nLine: %s", e.ReleaseVersion, e.ReleaseDate, e.Reason, e.Line)
}

func main() {
	rootCmd := newRootCmd()
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(1)
	}
}

func newRootCmd() *cobra.Command {
	rootCmd := &cobra.Command{
		Use:           "helmlog",
		Short:         "Validate and generate changelog artifacts",
		SilenceUsage:  true,
		SilenceErrors: true,
	}

	rootCmd.AddCommand(newValidateCmd())
	rootCmd.AddCommand(newGenerateCmd())

	return rootCmd
}

func newValidateCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "validate <CHANGELOG.md> [<CHANGELOG.md> ...]",
		Short: "Validate changelog formatting and tags",
		Args:  cobra.MinimumNArgs(1),
		RunE: func(_ *cobra.Command, args []string) error {
			return runValidate(args)
		},
	}
}

func runValidate(args []string) error {
	totalReleases := 0
	totalEntries := 0

	for _, path := range args {
		result, err := parseFile(path)
		if err != nil {
			return err
		}

		totalReleases += result.ReleaseCount
		totalEntries += result.EntryCount
	}

	fmt.Printf("OK: %d changelog file(s) validated\n", len(args))
	fmt.Printf("Releases parsed: %d\n", totalReleases)
	fmt.Printf("Entries kept: %d\n", totalEntries)

	return nil
}

func newGenerateCmd() *cobra.Command {
	outputPath := ""

	cmd := &cobra.Command{
		Use:   "generate <CHANGELOG.md>",
		Short: "Generate deterministic changelog artifact",
		Args:  cobra.ExactArgs(1),
		RunE: func(_ *cobra.Command, args []string) error {
			return runGenerate(args[0], outputPath)
		},
	}

	cmd.Flags().StringVarP(&outputPath, "output", "o", "", "Output file path (defaults to stdout)")

	return cmd
}

func runGenerate(changelogPath, outputPath string) error {
	result, err := parseFile(changelogPath)
	if err != nil {
		return err
	}

	sortReleasesNewestFirst(result.Log.Releases)

	output, err := marshalJSON(result.Log)
	if err != nil {
		return err
	}

	if outputPath == "" || outputPath == "-" {
		if _, err := os.Stdout.Write(output); err != nil {
			return fmt.Errorf("ERROR: failed to write output: %w", err)
		}
		return nil
	}

	if err := os.WriteFile(outputPath, output, 0o644); err != nil {
		return fmt.Errorf("ERROR: failed to write %s: %w", outputPath, err)
	}

	fmt.Printf("Wrote %s with %d releases and %d entries\n", outputPath, result.ReleaseCount, result.EntryCount)
	return nil
}

func parseFile(path string) (parseResult, error) {
	f, err := os.Open(path)
	if err != nil {
		return parseResult{}, fmt.Errorf("ERROR: failed to open %s: %w", path, err)
	}
	defer f.Close()

	return parseMarkdown(f)
}

func parseMarkdown(r io.Reader) (parseResult, error) {
	result := parseResult{}

	scanner := bufio.NewScanner(r)
	lineNumber := 0
	currentRelease := -1

	for scanner.Scan() {
		lineNumber++
		line := scanner.Text()
		indent := len(line) - len(strings.TrimLeft(line, " \t"))
		leftTrimmed := strings.TrimLeft(line, " \t")
		trimmed := strings.TrimSpace(line)

		if trimmed == "" {
			continue
		}

		if matches := releaseHeaderPattern.FindStringSubmatch(trimmed); matches != nil {
			if err := validateReleaseDate(matches[2]); err != nil {
				return parseResult{}, parseError{
					Reason: err.Error(),
					Line:   line,
				}
			}

			result.Log.Releases = append(result.Log.Releases, helmlog.Release{Version: matches[1], Date: matches[2]})
			currentRelease = len(result.Log.Releases) - 1
			result.ReleaseCount++
			continue
		}

		if strings.HasPrefix(trimmed, "### ") {
			return parseResult{}, parseError{
				ReleaseVersion: releaseVersion(result.Log.Releases, currentRelease),
				ReleaseDate:    releaseDate(result.Log.Releases, currentRelease),
				Reason:         `release header must match "### vX.Y.Z / YYYY-MM-DD"`,
				Line:           line,
			}
		}

		if strings.HasPrefix(trimmed, "#### Changes from opentelemetry-collector") {
			continue
		}

		if !strings.HasPrefix(leftTrimmed, "- ") {
			continue
		}

		if indent > 0 {
			if currentRelease < 0 || len(result.Log.Releases[currentRelease].Entries) == 0 {
				return parseResult{}, parseError{
					ReleaseVersion: releaseVersion(result.Log.Releases, currentRelease),
					ReleaseDate:    releaseDate(result.Log.Releases, currentRelease),
					Reason:         "sublevel entry must follow a top-level tagged entry",
					Line:           line,
				}
			}

			sublevelText := strings.TrimSpace(strings.TrimPrefix(leftTrimmed, "- "))
			if sublevelText == "" {
				return parseResult{}, parseError{
					ReleaseVersion: result.Log.Releases[currentRelease].Version,
					ReleaseDate:    result.Log.Releases[currentRelease].Date,
					Reason:         "sublevel entry text must not be empty",
					Line:           line,
				}
			}

			last := len(result.Log.Releases[currentRelease].Entries) - 1
			result.Log.Releases[currentRelease].Entries[last].Text += "\n- " + sublevelText
			continue
		}

		if strings.Contains(trimmed, droppedEntryPhrase) {
			continue
		}

		if currentRelease < 0 {
			return parseResult{}, parseError{
				Reason: fmt.Sprintf("entry found before first release header at line %d", lineNumber),
				Line:   line,
			}
		}

		tags, text, ok := parseEntry(trimmed)
		if !ok {
			return parseResult{}, parseError{
				ReleaseVersion: result.Log.Releases[currentRelease].Version,
				ReleaseDate:    result.Log.Releases[currentRelease].Date,
				Reason:         `entry must match "- [Tag] text..."`,
				Line:           line,
			}
		}

		for _, tag := range tags {
			if err := validateTag(tag); err != nil {
				return parseResult{}, parseError{
					ReleaseVersion: result.Log.Releases[currentRelease].Version,
					ReleaseDate:    result.Log.Releases[currentRelease].Date,
					Reason:         err.Error(),
					Line:           line,
				}
			}
		}

		if text == "" {
			return parseResult{}, parseError{
				ReleaseVersion: result.Log.Releases[currentRelease].Version,
				ReleaseDate:    result.Log.Releases[currentRelease].Date,
				Reason:         "entry text must not be empty",
				Line:           line,
			}
		}

		result.Log.Releases[currentRelease].Entries = append(result.Log.Releases[currentRelease].Entries, helmlog.Entry{
			Tag:  normalizeTag(selectPrimaryTag(tags)),
			Text: text,
		})
		result.EntryCount++
	}

	if err := scanner.Err(); err != nil {
		return parseResult{}, fmt.Errorf("ERROR: failed reading changelog: %w", err)
	}

	if result.ReleaseCount == 0 {
		return parseResult{}, errors.New("ERROR: no releases found")
	}

	return result, nil
}

func validateTag(tag string) error {
	normalized := strings.ToLower(strings.TrimSpace(tag))
	if !allowedTags[normalized] {
		return fmt.Errorf("unknown tag %q", "["+tag+"]")
	}

	return nil
}

func normalizeTag(tag string) string {
	normalized := strings.ToLower(strings.TrimSpace(tag))
	switch normalized {
	case "feat", "feature":
		return "Feat"
	case "fix", "bug":
		return "Fix"
	case "change", ":warning: change":
		return "Change"
	case "breaking", ":warning: breaking change":
		return "Breaking"
	case "chore":
		return "Chore"
	case "revert":
		return "Revert"
	case "update":
		return "Update"
	case "docs":
		return "Docs"
	default:
		return tag
	}
}

func parseEntry(line string) ([]string, string, bool) {
	rest := strings.TrimSpace(strings.TrimPrefix(line, "- "))
	tags := make([]string, 0, 1)

	for strings.HasPrefix(rest, "[") {
		end := strings.IndexByte(rest, ']')
		if end <= 1 {
			return nil, "", false
		}

		tag := strings.TrimSpace(rest[1:end])
		if tag == "" {
			return nil, "", false
		}

		tags = append(tags, tag)
		rest = strings.TrimSpace(rest[end+1:])
	}

	if len(tags) == 0 || rest == "" {
		return nil, "", false
	}

	return tags, rest, true
}

func selectPrimaryTag(tags []string) string {
	for i := len(tags) - 1; i >= 0; i-- {
		normalized := strings.ToLower(strings.TrimSpace(tags[i]))
		if normalized != ":warning: change" && normalized != ":warning: breaking change" {
			return tags[i]
		}
	}

	return tags[len(tags)-1]
}

func releaseVersion(releases []helmlog.Release, index int) string {
	if index < 0 || index >= len(releases) {
		return ""
	}

	return releases[index].Version
}

func releaseDate(releases []helmlog.Release, index int) string {
	if index < 0 || index >= len(releases) {
		return ""
	}

	return releases[index].Date
}

func sortReleasesNewestFirst(releases []helmlog.Release) {
	sort.SliceStable(releases, func(i, j int) bool {
		if releases[i].Date != releases[j].Date {
			return releases[i].Date > releases[j].Date
		}

		vi := parseVersion(releases[i].Version)
		vj := parseVersion(releases[j].Version)
		if vi[0] != vj[0] {
			return vi[0] > vj[0]
		}
		if vi[1] != vj[1] {
			return vi[1] > vj[1]
		}
		if vi[2] != vj[2] {
			return vi[2] > vj[2]
		}

		return i < j
	})
}

func parseVersion(version string) [3]int {
	stripped := strings.TrimPrefix(version, "v")
	parts := strings.Split(stripped, ".")
	var out [3]int
	for i := 0; i < len(parts) && i < 3; i++ {
		v, err := strconv.Atoi(parts[i])
		if err != nil {
			return out
		}
		out[i] = v
	}

	return out
}

func validateReleaseDate(date string) error {
	releaseDate, err := time.Parse("2006-01-02", date)
	if err != nil {
		return fmt.Errorf("invalid release date %q", date)
	}

	today := time.Now().UTC().Truncate(24 * time.Hour)
	if releaseDate.After(today) {
		return fmt.Errorf("release date must not be in the future: %s", date)
	}

	return nil
}

func marshalJSON(log helmlog.Changelog) ([]byte, error) {
	output, err := json.MarshalIndent(log, "", "  ")
	if err != nil {
		return nil, fmt.Errorf("ERROR: failed to encode json: %w", err)
	}
	output = append(output, '\n')
	return output, nil
}
