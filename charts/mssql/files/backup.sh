#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
umask 077

fail() { printf 'Backup failed: %s\n' "$1" >&2; exit 1; }
[[ -n ${SQL_HOST:-} && -n ${SQLCMDUSER:-} && -n ${SQLCMDPASSWORD:-} ]] || fail 'SQL connection credentials are required'
[[ ${SQL_PORT:-1433} =~ ^[0-9]+$ ]] || fail 'invalid SQL port'
[[ -n ${BACKUP_DATABASES:-} ]] || fail 'an explicit database list is required'
[[ ${BACKUP_COMPRESSION:-false} == true || ${BACKUP_COMPRESSION:-false} == false ]] || fail 'invalid compression setting'
[[ -d /backup && ! -L /backup && -d /work && ! -L /work ]] || fail 'staging mounts are unavailable'
sqlcmd=/opt/mssql-tools18/bin/sqlcmd
[[ -x "$sqlcmd" ]] || fail 'the official image must provide sqlcmd tools18'

read -r -a databases <<< "$BACKUP_DATABASES"
declare -A seen=()
for database in "${databases[@]}"; do
  [[ "$database" =~ ^[A-Za-z_][A-Za-z0-9_]{0,127}$ ]] || fail 'database names must be ASCII letters, digits and underscores, starting with a letter or underscore'
  [[ -z ${seen[$database]:-} ]] || fail 'database list contains duplicates'
  seen[$database]=1
done
random="$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
[[ "$random" =~ ^[0-9a-f]{16}$ ]] || fail 'could not generate a unique run identifier'
run_id="mssql-$(date -u +%Y%m%dT%H%M%SZ)-${random}"
run_dir="/backup/${run_id}"
mkdir -- "$run_dir"
owned_archives=()
on_exit() {
  status=$?
  trap - EXIT TERM INT
  if (( status != 0 )); then
    # Only paths created by this invocation are eligible; never scan other runs.
    if [[ -d "$run_dir" && ! -L "$run_dir" && ! -L /backup ]]; then
      for archive in "${owned_archives[@]}"; do
        if [[ -f "$archive" && ! -L "$archive" ]]; then rm -- "$archive" || true; fi
      done
      rmdir -- "$run_dir" 2>/dev/null || true
      diagnostic="/backup/.last-failure-${run_id}"
      if (set -o noclobber; printf '{"runId":"%s","phase":"native","exitCode":%s,"failedAt":%s}\n' \
        "$run_id" "$status" "$(date -u +%s)" > "$diagnostic"); then
        mv -T -- "$diagnostic" /backup/.last-failure || true
      fi
    fi
    printf 'Native backup failed; owned archives removed where possible, latest diagnostic: /backup/.last-failure\n' >&2
  fi
  exit "$status"
}
trap on_exit EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
# The server and worker use the same UID; archive files remain private.
printf '%s\n' "$run_id" > /work/run-id
: > /work/files.tsv
compression=NO_COMPRESSION
[[ ${BACKUP_COMPRESSION:-false} == true ]] && compression=COMPRESSION
printf '{"schemaVersion":1,"runId":"%s","createdAt":"%s","backupType":"full-copy-only","checksum":true,"compression":%s,"files":[' \
  "$run_id" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${BACKUP_COMPRESSION:-false}" > /work/manifest.json.tmp
separator=''
for database in "${databases[@]}"; do
  file="${database}.bak"
  archive="${run_dir}/${file}"
  owned_archives+=("$archive")
  # Identifiers and generated paths passed above have no SQL metacharacters.
  printf "BACKUP DATABASE [%s] TO DISK = N'%s' WITH COPY_ONLY, CHECKSUM, %s, STATS = 10;\nGO\n" \
    "$database" "$archive" "$compression" | \
    "$sqlcmd" -S "tcp:${SQL_HOST},${SQL_PORT:-1433}" -U "$SQLCMDUSER" -N -b -V 11 -r 1 -x -l 30 -t 0
  [[ -f "$archive" && ! -L "$archive" && -s "$archive" ]] || fail 'SQL did not produce a readable archive'
  hash="$(sha256sum -- "$archive")"; hash="${hash%% *}"
  size="$(stat -c %s -- "$archive")"
  [[ "$hash" =~ ^[0-9a-f]{64}$ && "$size" =~ ^[0-9]+$ ]] || fail 'could not inspect the completed archive'
  printf '%s\t%s\t%s\t%s\n' "$database" "$file" "$size" "$hash" >> /work/files.tsv
  printf '%s{"database":"%s","file":"%s","sizeBytes":%s,"sha256":"%s"}' \
    "$separator" "$database" "$file" "$size" "$hash" >> /work/manifest.json.tmp
  separator=,
done
printf ']}\n' >> /work/manifest.json.tmp
mv -- /work/manifest.json.tmp /work/manifest.json
printf 'Native backup completed: %s (%s databases)\n' "$run_id" "${#databases[@]}"
