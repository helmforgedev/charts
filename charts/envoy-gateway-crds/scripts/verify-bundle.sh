#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="$CHART_DIR/BUNDLE.lock.yaml"
GATEWAY_FILE="$CHART_DIR/charts/gateway-api-crds/crds/gatewayapi-crds.yaml"
ENVOY_DIR="$CHART_DIR/charts/envoy-gateway-extension-crds/crds"

sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}

normalized_hash() {
  tr -d '\r' < "$1" | sha256_stream
}

pre_overlay_hash() {
  sed \
    -e '/^[[:space:]]*helmforge.dev\/bundle-name:/d' \
    -e '/^[[:space:]]*helmforge.dev\/bundle-version:/d' \
    -e '/^[[:space:]]*helmforge.dev\/source-sha256:/d' \
    "$1" | tr -d '\r' | sha256_stream
}

gateway_expected="$(awk '/^  preOverlaySha256: [a-f0-9]+$/ { print $2; exit }' "$LOCK_FILE")"
gateway_actual="$(normalized_hash "$GATEWAY_FILE")"
[[ "$gateway_actual" == "$gateway_expected" ]] || {
  echo "Gateway API bundle digest mismatch: expected $gateway_expected, got $gateway_actual" >&2
  exit 1
}

verified=0
while read -r file expected; do
  [[ -n "$file" ]] || continue
  path="$ENVOY_DIR/$file"
  [[ -f "$path" ]] || {
    echo "Missing locked Envoy Gateway CRD: $file" >&2
    exit 1
  }
  actual="$(pre_overlay_hash "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "Envoy Gateway CRD digest mismatch for $file: expected $expected, got $actual" >&2
    exit 1
  }
  annotation="$(awk '/helmforge.dev\/source-sha256:/ { print $2; exit }' "$path")"
  [[ "$annotation" == "$expected" ]] || {
    echo "Envoy Gateway CRD source annotation mismatch for $file" >&2
    exit 1
  }
  verified=$((verified + 1))
done < <(
  awk '
    /^  preOverlaySha256:$/ { in_envoy_hashes=1; next }
    /^metadataOverlay:/ { in_envoy_hashes=0 }
    in_envoy_hashes && /^    [^:]+\.yaml: [a-f0-9]+$/ {
      name=$1
      sub(/:$/, "", name)
      print name, $2
    }
  ' "$LOCK_FILE"
)

[[ "$verified" -eq 8 ]] || {
  echo "Expected 8 locked Envoy Gateway CRDs, verified $verified" >&2
  exit 1
}

actual_files="$(find "$ENVOY_DIR" -maxdepth 1 -type f -name '*.yaml' | wc -l | tr -d ' ')"
[[ "$actual_files" -eq 8 ]] || {
  echo "Expected exactly 8 Envoy Gateway CRD files, found $actual_files" >&2
  exit 1
}

echo "Verified Gateway API bundle and 8 Envoy Gateway CRDs against BUNDLE.lock.yaml"
