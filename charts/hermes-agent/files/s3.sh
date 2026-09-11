#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
umask 077
if [[ "$1" == download && -f /work/skip-restore ]]; then exit 0; fi
fail() { printf 'S3 operation failed: %s\n' "$1" >&2; exit 1; }
export AWS_PAGER='' AWS_EC2_METADATA_DISABLED=true
[[ ${S3_BUCKET:-} =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]] || fail 'invalid bucket'
[[ ${S3_PREFIX:-} =~ ^[A-Za-z0-9][A-Za-z0-9/_-]*$ && "$S3_PREFIX" != */ ]] || fail 'invalid prefix'
endpoint=()
if [[ -n ${S3_ENDPOINT:-} ]]; then
  case "$S3_ENDPOINT" in
    https://*) ;;
    http://*) [[ ${ALLOW_INSECURE_ENDPOINT:-false} == true ]] || fail 'HTTPS required' ;;
    *) fail 'invalid endpoint' ;;
  esac
  [[ "$S3_ENDPOINT" != *'@'* ]] || fail 'endpoint must not contain credentials'
  endpoint=(--endpoint-url "$S3_ENDPOINT")
fi
cloud() { aws "${endpoint[@]}" --region "$S3_REGION" "$@"; }
encryption=()
case ${S3_SSE:-} in
  '') ;;
  AES256) encryption=(--sse AES256) ;;
  aws:kms) encryption=(--sse aws:kms --sse-kms-key-id "$S3_KMS_KEY_ID") ;;
  *) fail 'invalid encryption mode' ;;
esac
case "$1" in
  upload)
    IFS=$'\t' read -r run size checksum < /work/upload.tsv
    [[ "$run" =~ ^hermes-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{16}$ && "$size" =~ ^[0-9]+$ && "$checksum" =~ ^[0-9a-f]{64}$ ]] || fail 'invalid snapshot metadata'
    [[ -f /work/backup.zip && ! -L /work/backup.zip && -s /work/manifest.json ]] || fail 'missing completed archive'
    [[ $(stat -c %s /work/backup.zip) == "$size" ]] || fail 'local size changed'
    actual=$(sha256sum /work/backup.zip); actual=${actual%% *}
    [[ "$actual" == "$checksum" ]] || fail 'local checksum changed'
    target="s3://${S3_BUCKET}/${S3_PREFIX}/${run}"
    cloud s3 cp /work/backup.zip "${target}/backup.zip" --only-show-errors "${encryption[@]}"
    actual=$(cloud s3 cp "${target}/backup.zip" - --only-show-errors | sha256sum); actual=${actual%% *}
    [[ "$actual" == "$checksum" ]] || fail 'remote byte verification failed'
    cloud s3 cp /work/manifest.json "${target}/manifest.json" --only-show-errors "${encryption[@]}" --content-type application/json
    printf 'Backup committed and remote archive verified: %s/manifest.json\n' "$target"
    ;;
  download)
    [[ ${RESTORE_MANIFEST_KEY:-} =~ ^[A-Za-z0-9][A-Za-z0-9/_-]*/manifest\.json$ ]] || fail 'invalid manifest key'
    [[ ${MAX_ARCHIVE_BYTES:-} =~ ^[0-9]+$ ]] || fail 'invalid archive size limit'
    target="s3://${S3_BUCKET}/${RESTORE_MANIFEST_KEY%/manifest.json}"
    cloud s3 cp "${target}/manifest.json" - --only-show-errors | head -c 20971521 > /work/manifest.json
    [[ $(stat -c %s /work/manifest.json) -le 20971520 ]] || fail 'manifest too large'
    cloud s3 cp "${target}/backup.zip" - --only-show-errors | head -c "$((MAX_ARCHIVE_BYTES + 1))" > /work/backup.zip
    [[ $(stat -c %s /work/backup.zip) -le "$MAX_ARCHIVE_BYTES" ]] || fail 'archive too large'
    ;;
  *) fail 'unknown operation' ;;
esac
