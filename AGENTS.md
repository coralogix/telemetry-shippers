# AGENTS instructions for Codex contributors

These rules apply to the `telemetry-shippers` repository when working through the Codex web UI.

## Harness ownership

This repository owns the downstream validation harness for the OpenTelemetry Collector Helm chart upgrade flow.

Use:

- [ARCHITECTURE.md](ARCHITECTURE.md) for ownership and workflow boundaries
- [docs/agent-runbooks/opentelemetry-collector-chart-upgrade.md](docs/agent-runbooks/opentelemetry-collector-chart-upgrade.md) for the full upgrade-validation workflow
- [docs/references](docs/references) for pinned validation and release references

## Downstream test boundary

Do not modify downstream tests, fixtures, or expected outputs unless explicitly requested.

## Flaky tests

When e2e tests fail, distinguish between:

1. real upstream regression
2. invalid downstream expectation
3. true flakiness

Only classify a failure as flaky when there is evidence.

If the failure is flaky and the user has not forbidden test edits, call a subagent focused on stabilizing that test without weakening coverage.
