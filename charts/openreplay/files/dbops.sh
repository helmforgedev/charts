#!/bin/bash
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

readonly target="${2:?migration target is required}"
readonly helper_root=/opt/openreplay/openreplay/scripts/helmcharts/openreplay/files
readonly schema_root=/opt/openreplay/openreplay/scripts/schema
readonly desired_version="${CHART_APP_VERSION#v}"
previous_version="${PREVIOUS_APP_VERSION:-${OPENREPLAY_VERSION:-}}"
previous_version="${previous_version#v}"
mode="$1"

if [[ -n "${OPENREPLAY_VERSION:-}" || "${FORCE_MIGRATION:-false}" == "true" ]]; then
  mode=true
fi

run_helper() {
  local operation="$1"
  local versions="${2:-}"
  case "$target" in
    postgresql) /bin/bash "$helper_root/postgresql.sh" "$operation" "$versions" ;;
    clickhouse) /bin/bash "$helper_root/clickhouse.sh" "$operation" "$versions" ;;
    minio) /bin/bash "$helper_root/minio.sh" "$operation" "$versions" ;;
    *) echo "Unsupported schema target: $target" >&2; exit 1 ;;
  esac
}

initialize() {
  case "$target" in
    postgresql|clickhouse) run_helper init ;;
    minio) run_helper migrate ;;
    *) run_helper invalid ;;
  esac
}

migrate() {
  if [[ -z "$previous_version" ]]; then
    echo "PREVIOUS_APP_VERSION is required for migration" >&2
    exit 100
  fi
  if [[ "$previous_version" == "$desired_version" && "${FORCE_MIGRATION:-false}" != "true" ]]; then
    echo "No OpenReplay application version change"
    return
  fi

  local selected=()
  local version
  while IFS= read -r version; do
    if [[ "${version//./}" -gt "${previous_version//./}" ]]; then
      selected+=("$version")
    fi
  done < <(find "$schema_root/db/init_dbs/$target" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | grep -v create | sort -V)

  local version_list
  version_list=$(IFS=,; echo "${selected[*]}")
  run_helper migrate "$version_list"
}

if [[ "$mode" == "true" ]]; then
  migrate
else
  initialize
fi

