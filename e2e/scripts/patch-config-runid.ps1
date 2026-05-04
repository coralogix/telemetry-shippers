# patch-config-runid.ps1 -- inject e2e.run_id resource attribute into an OTel config.
#
# Usage: .\patch-config-runid.ps1 <config-yaml-path> <run-id>
#
# Windows equivalent of patch-config-runid.sh. Requires `yq` (mikefarah/yq) on PATH.
# Install via `choco install yq` on GitHub Actions windows-latest runners.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Config,

    [Parameter(Mandatory=$true, Position=1)]
    [string]$RunId
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Config)) {
    Write-Error "config file not found: $Config"
    exit 1
}

if (-not (Get-Command yq -ErrorAction SilentlyContinue)) {
    Write-Error "yq not found in PATH"
    exit 1
}

# The standalone charts all use a processor named "resource/metadata" (with slash).
# We append (not replace) an e2e.run_id entry to its existing attributes list.
$expr = @"
  .processors."resource/metadata".attributes = (.processors."resource/metadata".attributes // [])
  | .processors."resource/metadata".attributes |= map(select(.key != "e2e.run_id"))
  | .processors."resource/metadata".attributes += [{"action": "upsert", "key": "e2e.run_id", "value": "$RunId"}]
"@

yq -i $expr $Config

# Sanity check: ensure the processor is referenced in at least one pipeline.
$check = yq -e '.service.pipelines[].processors[] | select(. == "resource/metadata")' $Config 2>$null
if (-not $check) {
    Write-Error "'resource/metadata' processor is not referenced in any pipeline. Patch had no effect."
    exit 1
}

Write-Host "Patched $Config with e2e.run_id=$RunId"
