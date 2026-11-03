#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  cat <<'EOF' >&2
Usage: update-fleet-manager-collector-releases.sh <collector-version> <collector-releases-dir>

Fetch one stable upstream Collector release with published SHA256 and Sigstore
bundle assets. Requires gh, jq, xxd, and GITHUB_TOKEN. Existing files are kept.
EOF
  exit 1
fi

version="${1#v}"
catalog_dir="$2"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Expected a Collector version such as 0.164.0." >&2
  exit 1
fi

if [ -f "$catalog_dir/$version.json" ]; then
  echo "Collector $version already exists; keeping its release data."
  exit 0
fi

export GH_TOKEN="${GITHUB_TOKEN:?Set GITHUB_TOKEN to authenticate GitHub requests.}"
api="repos/open-telemetry/opentelemetry-collector-releases"
mkdir -p "$catalog_dir"
work_dir="$(mktemp -d "$catalog_dir/.collector-release.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

gh api "$api/releases/tags/v$version" > "$work_dir/release.json"
jq -e --arg tag "v$version" \
  '.tag_name == $tag and .draft == false and .prerelease == false' \
  "$work_dir/release.json" > /dev/null
release_id="$(jq -er '.id' "$work_dir/release.json")"
# GitHub can truncate the assets embedded in the release response.
gh api --paginate --slurp "$api/releases/$release_id/assets?per_page=100" \
  | jq 'add' > "$work_dir/assets.json"
jq -c '.[] | select(.name | test("^otelcol-contrib_[0-9]+\\.[0-9]+\\.[0-9]+_[a-z0-9]+_[a-z0-9]+\\.tar\\.gz$"))' \
  "$work_dir/assets.json" > "$work_dir/archives.jsonl"

download_asset() {
  local name="$1" output="$2" id
  id="$(jq -er --arg name "$name" \
    'first(.[] | select(.name == $name) | .id) // error("Missing release asset: " + $name)' \
    "$work_dir/assets.json")"
  gh api -H 'Accept: application/octet-stream' "$api/releases/assets/$id" > "$output"
}

: > "$work_dir/artifacts.jsonl"
while IFS= read -r asset; do
  archive="$(jq -r '.name' <<< "$asset")"
  download_asset "$archive.sha256" "$work_dir/checksum"
  download_asset "$archive.sigstore.json" "$work_dir/bundle.json"
  checksum="$(awk '{print $1}' "$work_dir/checksum")"
  if [[ ! "$checksum" =~ ^[a-f0-9]{64}$ ]]; then
    echo "Invalid SHA256 for $archive." >&2
    exit 1
  fi
  digest="$(printf '%s' "$checksum" | xxd -r -p | base64 | tr -d '\n')"
  jq -e --arg digest "$digest" '
    (.mediaType | startswith("application/vnd.dev.sigstore.bundle.")) and
    .messageSignature.messageDigest.algorithm == "SHA2_256" and
    .messageSignature.messageDigest.digest == $digest and
    (.messageSignature.signature | length > 0) and
    (.verificationMaterial | type == "object" and length > 0)
  ' "$work_dir/bundle.json" > /dev/null

  jq -n --argjson asset "$asset" --arg version "$version" --arg checksum "$checksum" \
    --rawfile bundle "$work_dir/bundle.json" '
    ($asset.name | capture("^otelcol-contrib_(?<version>[0-9.]+)_(?<os>[a-z0-9]+)_(?<arch>[a-z0-9]+)\\.tar\\.gz$")) as $platform |
    if $platform.version != $version then error("Archive version disagrees with release")
    elif ($asset.digest // "") != "" and $asset.digest != ("sha256:" + $checksum)
      then error("GitHub asset digest disagrees with checksum")
    else {
      os: $platform.os,
      arch: $platform.arch,
      download_url: $asset.browser_download_url,
      sha256: $checksum,
      sigstore_bundle: $bundle,
      github_asset_id: $asset.id
    } + (if ($asset.digest // "") == "" then {} else {github_asset_digest: $asset.digest} end)
    end
  ' >> "$work_dir/artifacts.jsonl"
done < "$work_dir/archives.jsonl"

jq -n --slurpfile release "$work_dir/release.json" --slurpfile artifacts "$work_dir/artifacts.jsonl" '
  if ($artifacts | length) == 0 then error("Release has no contrib archives") else
  {
    version: ($release[0].tag_name | ltrimstr("v")),
    github_tag: $release[0].tag_name,
    github_release_id: $release[0].id,
    published_at: $release[0].published_at,
    artifacts: ($artifacts | sort_by(.os, .arch))
  } end
' > "$work_dir/catalog.json"

mv "$work_dir/catalog.json" "$catalog_dir/$version.json"
echo "Fetched Collector $version into $catalog_dir/$version.json."
