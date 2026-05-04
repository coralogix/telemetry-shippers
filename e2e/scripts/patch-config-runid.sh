#!/bin/bash
# patch-config-runid.sh -- inject e2e.run_id resource attribute into an OTel config.
#
# Usage: patch-config-runid.sh <config-yaml-path> <run-id>
#
# This is the minimum patch standalone E2E tests need: every signal emitted by the
# collector will carry a resource attribute "e2e.run_id" with the test run's unique
# identifier. The verify CLI uses this attribute to isolate this run's data from
# everything else in the Coralogix account.
#
# Looks for the resource processor's attributes list. If the processor or list does
# not exist, creates them. Idempotent: re-running with the same run-id is a no-op.

set -euo pipefail

CONFIG=${1:?"usage: patch-config-runid.sh <config-yaml-path> <run-id>"}
RUN_ID=${2:?"usage: patch-config-runid.sh <config-yaml-path> <run-id>"}

if [ ! -f "$CONFIG" ]; then
  echo "ERROR: config file not found: $CONFIG" >&2
  exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
  echo "ERROR: yq not found in PATH" >&2
  exit 1
fi

# The standalone charts all use a processor named "resource/metadata" (with slash).
# We append (not replace) an e2e.run_id entry to its existing attributes list, so
# pre-existing attributes like cx.otel_integration.name are preserved.
#
# Pipeline (yq syntax — mikefarah/yq Go version):
#   1. Initialize processors."resource/metadata".attributes to [] if missing
#   2. Drop any existing e2e.run_id entry (so re-runs replace, not duplicate)
#   3. Append the new e2e.run_id entry with action: upsert (matches existing entries)
PROCESSOR='"resource/metadata"'

yq -i "
  .processors.${PROCESSOR}.attributes = (.processors.${PROCESSOR}.attributes // [])
  | .processors.${PROCESSOR}.attributes |= map(select(.key != \"e2e.run_id\"))
  | .processors.${PROCESSOR}.attributes += [{\"action\": \"upsert\", \"key\": \"e2e.run_id\", \"value\": \"${RUN_ID}\"}]
" "$CONFIG"

# Sanity check: verify the processor is actually used in at least one pipeline.
# If not, the patch had no effect on emitted telemetry — fail loudly.
if ! yq -e '.service.pipelines[].processors[] | select(. == "resource/metadata")' "$CONFIG" >/dev/null 2>&1; then
  echo "WARN: 'resource/metadata' processor is not referenced in any pipeline." >&2
  echo "      e2e.run_id will NOT be added to emitted telemetry. Patch had no effect." >&2
  exit 1
fi

echo "Patched $CONFIG with e2e.run_id=${RUN_ID}"
