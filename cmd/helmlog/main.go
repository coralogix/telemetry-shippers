package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
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
	nowFunc              = time.Now
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

type osMappingResult struct {
	Mappings []osMappingEntry `json:"mappings"`
}

type osMappingEntry struct {
	ChartVersion          string `json:"chart_version"`
	CollectorChartVersion string `json:"collector_chart_version"`
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
	rootCmd.AddCommand(newOSMappingCmd())

	return rootCmd
}

func newOSMappingCmd() *cobra.Command {
	osFlag := "linux"
	outputPath := ""
	historyRef := "HEAD"

	cmd := &cobra.Command{
		Use:   "os-mapping [os]",
		Short: "Generate chart to collector version mapping for one OS",
		Args:  cobra.NoArgs,
		RunE: func(_ *cobra.Command, args []string) error {
			return runOSMapping(osFlag, outputPath, historyRef)
		},
	}

	cmd.Flags().StringVar(&osFlag, "os", "linux", "Target OS (linux|macos|windows; aliases: mac,darwin,win)")
	cmd.Flags().StringVarP(&outputPath, "output", "o", "", "Output file path (defaults to stdout)")
	cmd.Flags().StringVar(&historyRef, "ref", "HEAD", "Git ref whose history will be scanned")

	return cmd
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

func runOSMapping(inputOS, outputPath, historyRef string) error {
	normalizedOS, err := normalizeOS(inputOS)
	if err != nil {
		return err
	}

	repoRoot, err := gitRepoRoot()
	if err != nil {
		return err
	}

	chartFile := filepath.Join(fmt.Sprintf("otel-%s-standalone", normalizedOS), "Chart.yaml")
	if _, err := os.Stat(filepath.Join(repoRoot, chartFile)); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return fmt.Errorf("ERROR: chart file not found for OS %q: %s", normalizedOS, chartFile)
		}
		return fmt.Errorf("ERROR: failed to access chart file %s: %w", chartFile, err)
	}

	result, err := buildOSMapping(repoRoot, chartFile, historyRef)
	if err != nil {
		return err
	}

	output, err := marshalOSMappingJSON(result)
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

	fmt.Printf("Wrote %s with %d mappings\n", outputPath, len(result.Mappings))

	return nil
}

func buildOSMapping(repoRoot, chartFile, historyRef string) (osMappingResult, error) {
	hashes, err := gitHistoryHashesForPath(repoRoot, historyRef, chartFile)
	if err != nil {
		return osMappingResult{}, err
	}

	result := osMappingResult{Mappings: make([]osMappingEntry, 0)}
	deduplicationMap := map[string]string{}
	orderKeeper := []string{}
	for _, hash := range hashes {
		if hash == "" {
			continue
		}

		chartSnapshot, err := runGitCommand(repoRoot, "show", fmt.Sprintf("%s:%s", hash, chartFile))
		if err != nil {
			continue
		}

		chartVersion, collectorVersion := extractVersionsFromChart(chartSnapshot)
		if chartVersion == "" || collectorVersion == "" {
			continue
		}

		if _, ok := deduplicationMap[chartVersion]; !ok {
			orderKeeper = append(orderKeeper, chartVersion)
			deduplicationMap[chartVersion] = collectorVersion
			continue
		}
	}

	for _, chartVersion := range orderKeeper {
		result.Mappings = append(result.Mappings, osMappingEntry{
			ChartVersion:          chartVersion,
			CollectorChartVersion: deduplicationMap[chartVersion],
		})
	}

	return result, nil
}

func gitHistoryHashesForPath(repoRoot, historyRef, chartFile string) ([]string, error) {
	historyRef = strings.TrimSpace(historyRef)
	if historyRef == "" {
		historyRef = "HEAD"
	}

	hashesOutput, err := runGitCommand(repoRoot, "log", historyRef, "--format=%H", "--", chartFile)
	if err != nil {
		return nil, fmt.Errorf("ERROR: failed to read git history for %s at ref %q: %w", chartFile, historyRef, err)
	}

	hashes := strings.Split(strings.TrimSpace(hashesOutput), "\n")
	for i := range hashes {
		hashes[i] = strings.TrimSpace(hashes[i])
	}

	return hashes, nil
}

func normalizeOS(value string) (string, error) {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "", "linux":
		return "linux", nil
	case "macos", "mac", "darwin":
		return "macos", nil
	case "windows", "win":
		return "windows", nil
	default:
		return "", fmt.Errorf("ERROR: unsupported OS %q (supported: linux, macos|mac|darwin, windows|win)", value)
	}
}

func gitRepoRoot() (string, error) {
	root, err := runGitCommand("", "rev-parse", "--show-toplevel")
	if err != nil {
		return "", fmt.Errorf("ERROR: failed to determine repository root: %w", err)
	}

	return strings.TrimSpace(root), nil
}

func runGitCommand(workdir string, args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	if workdir != "" {
		cmd.Dir = workdir
	}

	output, err := cmd.CombinedOutput()
	if err != nil {
		trimmed := strings.TrimSpace(string(output))
		if trimmed == "" {
			return "", err
		}
		return "", fmt.Errorf("%w: %s", err, trimmed)
	}

	return string(output), nil
}

func extractVersionsFromChart(chartContent string) (string, string) {
	lines := strings.Split(chartContent, "\n")
	chartVersion := ""
	collectorVersion := ""

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" {
			continue
		}

		indent := len(line) - len(strings.TrimLeft(line, " \t"))
		if indent == 0 && strings.HasPrefix(trimmed, "version:") {
			chartVersion = normalizeYAMLScalar(strings.TrimSpace(strings.TrimPrefix(trimmed, "version:")))
			break
		}
	}

	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if !strings.HasPrefix(trimmed, "- name:") {
			continue
		}

		name := strings.TrimSpace(strings.TrimPrefix(trimmed, "- name:"))
		if name != "opentelemetry-collector" {
			continue
		}

		depIndent := len(line) - len(strings.TrimLeft(line, " \t"))
		for j := i + 1; j < len(lines); j++ {
			nextLine := lines[j]
			nextTrimmed := strings.TrimSpace(nextLine)
			if nextTrimmed == "" {
				continue
			}

			nextIndent := len(nextLine) - len(strings.TrimLeft(nextLine, " \t"))
			if nextIndent <= depIndent {
				break
			}

			if strings.HasPrefix(nextTrimmed, "version:") {
				collectorVersion = normalizeYAMLScalar(strings.TrimSpace(strings.TrimPrefix(nextTrimmed, "version:")))
				break
			}
		}

		break
	}

	return chartVersion, collectorVersion
}

func normalizeYAMLScalar(value string) string {
	value = strings.TrimSpace(value)
	if len(value) >= 2 {
		if (value[0] == '"' && value[len(value)-1] == '"') || (value[0] == '\'' && value[len(value)-1] == '\'') {
			return value[1 : len(value)-1]
		}
	}

	return value
}

func marshalOSMappingJSON(mapping osMappingResult) ([]byte, error) {
	output, err := json.MarshalIndent(mapping, "", "  ")
	if err != nil {
		return nil, fmt.Errorf("ERROR: failed to encode json: %w", err)
	}

	output = append(output, '\n')
	return output, nil
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

	today, err := time.Parse("2006-01-02", nowFunc().In(time.Local).Format("2006-01-02"))
	if err != nil {
		return fmt.Errorf("failed to determine current date: %w", err)
	}

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
