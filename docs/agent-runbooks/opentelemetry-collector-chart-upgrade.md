# OpenTelemetry Collector chart upgrade runbook

Use this runbook from `telemetry-shippers` when validating an upstream `opentelemetry-collector` chart upgrade against downstream integration tests.

## Ownership split

Changes belong in two places:

- upstream chart clone:
  - `charts/opentelemetry-collector/Chart.yaml`
  - `charts/opentelemetry-collector/CHANGELOG.md`
  - regenerated examples and any upstream chart fixes
- this repository:
  - temporary dependency rewiring for local validation
  - downstream e2e execution
  - downstream debugging notes
  - harness docs

Do not commit temporary `file://` dependency rewiring here unless explicitly requested.

## Repositories and files involved

- upstream chart repo: cloned from `git@github.com:coralogix/opentelemetry-helm-charts.git`
- local integration chart:
  - `otel-integration/k8s-helm/Chart.yaml`
- local e2e entrypoint:
  - `otel-integration/k8s-helm/e2e-test/run-all.sh`

## Release selection

1. Read the current upstream chart `appVersion` from `charts/opentelemetry-collector/Chart.yaml` in the upstream chart repo.
2. Inspect `https://github.com/open-telemetry/opentelemetry-collector-releases/releases`.
3. Pick the next base release after the current `appVersion`.
4. If that base release has patch releases, use the latest patch release as the target `appVersion`.
5. Review release notes from:
   - `https://github.com/open-telemetry/opentelemetry-collector/releases`
   - `https://github.com/open-telemetry/opentelemetry-collector-contrib/releases`

## Patch-release caveat

`opentelemetry-collector-releases` is the source of truth for the chart `appVersion`.

Sometimes `collector-releases` publishes a patch release without matching patch releases in `opentelemetry-collector` or `opentelemetry-collector-contrib`.

When that happens:

- keep the upstream chart `appVersion` on the `collector-releases` patch version
- summarize the nearest matching core and contrib release notes in the upstream chart changelog
- call out the mismatch explicitly in upgrade notes and PR text

## Commands

```bash
git clone git@github.com:coralogix/opentelemetry-helm-charts.git /path/to/upstream-clone
git -C /path/to/upstream-clone checkout -b upgrade-otel-collector-vX.Y.Z
sed -n '1,40p' /path/to/upstream-clone/charts/opentelemetry-collector/Chart.yaml
curl -fsSL 'https://api.github.com/repos/open-telemetry/opentelemetry-collector-releases/releases?per_page=20' | jq -r '.[].tag_name'
curl -fsSL 'https://api.github.com/repos/open-telemetry/opentelemetry-collector/releases/tags/vX.Y.Z'
curl -fsSL 'https://api.github.com/repos/open-telemetry/opentelemetry-collector-contrib/releases/tags/vX.Y.Z'
/path/to/upstream-clone/charts/opentelemetry-collector/validate-chart-version-bump.sh
make -C /path/to/upstream-clone generate-examples CHARTS=opentelemetry-collector
make -C /path/to/upstream-clone check-examples CHARTS=opentelemetry-collector
make -C /path/to/upstream-clone validate-examples
helm lint /path/to/upstream-clone/charts/opentelemetry-collector
helm dependency update otel-integration/k8s-helm
otel-integration/k8s-helm/e2e-test/run-all.sh
```

## Parallelizable work

These can be done in parallel:

- fetch release metadata from `collector-releases`, `collector`, and `collector-contrib`
- inspect current upstream `Chart.yaml`, `CHANGELOG.md`, and validation scripts
- scan this repo for dependency wiring and e2e entrypoints
- after a failure, inspect:
  - downstream test logs
  - live rendered Collector config
  - upstream core/contrib commit ranges for the selected release tags

Do not parallelize edits that must be applied to the same file or branch state.

## Validation flow

1. Upgrade the upstream chart in the upstream clone.
2. Run upstream chart validation there.
3. Temporarily point `otel-integration/k8s-helm/Chart.yaml` at the local upstream clone with `file://`.
4. Refresh Helm dependencies.
5. Run the downstream e2e suite.
6. Revert temporary downstream dependency rewiring after validation.

Do not modify downstream tests, fixtures, or expected outputs unless explicitly requested.

## Flaky tests

When running e2e tests, handle flaky tests explicitly.

After running:

- `otel-integration/k8s-helm/e2e-test/run-all.sh`

if any test fails, first determine whether the failure is caused by:

1. a real regression from the OpenTelemetry Collector or Helm chart upgrade
2. an invalid test expectation
3. test flakiness, timing, ordering, retries, readiness, cleanup, or environment instability

If the failure appears to be flaky, and the test intent is still valid, call a subagent focused only on stabilizing that test.

Subagent task:

Fix the flaky e2e test without weakening the test's intended coverage.

The subagent must:

- inspect the failing test and logs
- identify the flakiness root cause
- preserve the semantic assertion being tested
- avoid simply increasing sleeps unless there is no better option
- prefer deterministic readiness checks, polling with timeouts, retries around eventually-consistent operations, stable selectors, isolated test resources, and reliable cleanup
- avoid hiding real failures
- rerun the affected test multiple times to verify stability
- then rerun the full e2e suite

Acceptable fixes include:

- replacing fixed sleeps with readiness/wait loops
- waiting for Kubernetes resources to become ready
- making log/event assertions eventually consistent
- using unique resource names per test run
- improving cleanup between tests
- avoiding dependence on test execution order
- tightening selectors to avoid matching stale resources
- adding bounded retries for known eventually-consistent operations

Unacceptable fixes include:

- deleting the test
- skipping the test
- weakening assertions so the test no longer proves the intended behavior
- adding unbounded retries
- masking command failures
- ignoring non-zero exit codes
- treating a real Collector/chart regression as flakiness

The subagent must report:

- which test was flaky
- evidence that it was flaky
- root cause
- files changed
- why the fix preserves test coverage
- commands run
- repeated-test results
- full-suite result

Only classify a failure as flaky when there is evidence. If unsure, treat it as a real failure and investigate normally.

## Isolating regressions

If the downstream e2e suite fails after the upstream chart upgrade:

1. Record the exact failure from the downstream test logs.
2. Determine whether the breakage comes from:
   - collector runtime behavior
   - contrib component behavior
   - chart rendering/config changes
   - generated example drift
   - test expectation drift
   - true flakiness
3. Clone the upstream source repos at the release tags used by the selected distribution release:
   - `opentelemetry-collector`
   - `opentelemetry-collector-contrib`
4. Compare the selected tag against the previous working tag to identify the commit or change range that introduced the regression.
5. Use that isolation to propose:
   - a true upstream chart fix
   - a downstream compatibility update
   - a temporary workaround

Do not apply a workaround directly if it changes downstream expectations or semantics. Stop and ask what to do with the isolated finding first.
