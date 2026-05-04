#!/bin/bash
# wait-healthy.sh -- poll an OTel collector health endpoint until it returns 200
# or the timeout expires.
#
# Usage: wait-healthy.sh <url> [timeout-seconds]
#
# Examples:
#   wait-healthy.sh http://127.0.0.1:13133 60
#   wait-healthy.sh http://127.0.0.1:13133/healthcheck 300
#
# The collector's health_check extension serves on port 13133 by default and
# returns 200 OK when the pipeline is ready to accept telemetry. Polling here
# instead of "sleep 30" gives faster start when the collector boots quickly,
# and clear failure when it never starts.

set -euo pipefail

URL=${1:?"usage: wait-healthy.sh <url> [timeout-seconds]"}
TIMEOUT=${2:-60}
INTERVAL=5

START=$(date +%s)
ATTEMPT=0

echo "Waiting for collector health at ${URL} (timeout: ${TIMEOUT}s)..."

while true; do
  ATTEMPT=$((ATTEMPT + 1))
  if curl -sf -o /dev/null -m 3 "$URL"; then
    ELAPSED=$(( $(date +%s) - START ))
    echo "Collector is healthy after ${ELAPSED}s (attempt ${ATTEMPT})"
    exit 0
  fi

  ELAPSED=$(( $(date +%s) - START ))
  if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "ERROR: collector not healthy after ${TIMEOUT}s (${ATTEMPT} attempts)" >&2
    exit 1
  fi

  sleep $INTERVAL
done
