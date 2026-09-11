#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
umask 077

fail() { printf 'Upload failed: %s\n' "$1" >&2; exit 1; }
[[ ${S3_BUCKET:-} =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]] || fail 'invalid S3 bucket'
[[ ${S3_PREFIX:-} =~ ^[A-Za-z0-9][A-Za-z0-9/_-]*$ && "$S3_PREFIX" != */ ]] || fail 'a dedicated S3 prefix without a trailing slash is required'
[[ -n ${S3_REGION:-} ]] || fail 'S3 region is required'
endpoint_args=()
if [[ -n ${S3_ENDPOINT:-} ]]; then
  case "$S3_ENDPOINT" in
    https://*) ;;
    http://*) fail 'HTTPS is required' ;;
    *) fail 'unsupported S3 endpoint protocol' ;;
  esac
  [[ "$S3_ENDPOINT" != *'@'* ]] || fail 'credentials must not be embedded in the endpoint'
  endpoint_args=(--endpoint-url "$S3_ENDPOINT")
fi
sse_args=()
case "${S3_SSE:-}" in
  '') [[ -z ${S3_KMS_KEY_ID:-} ]] || fail 'KMS key requires aws:kms encryption' ;;
  AES256) [[ -z ${S3_KMS_KEY_ID:-} ]] || fail 'KMS key requires aws:kms encryption'; sse_args=(--sse AES256) ;;
  aws:kms) sse_args=(--sse aws:kms); [[ -z ${S3_KMS_KEY_ID:-} ]] || sse_args+=(--sse-kms-key-id "$S3_KMS_KEY_ID") ;;
  *) fail 'unsupported S3 server-side encryption mode' ;;
esac
[[ -f /work/run-id && -f /work/files.tsv && -s /work/manifest.json ]] || fail 'completed native backup metadata is missing'
read -r run_id < /work/run-id
[[ "$run_id" =~ ^mssql-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{16}$ ]] || fail 'invalid staging run identifier'
run_dir="/backup/${run_id}"
[[ -d "$run_dir" && ! -L "$run_dir" && ! -L /backup ]] || fail 'invalid staging directory'
target="s3://${S3_BUCKET}/${S3_PREFIX}/${run_id}"
export AWS_PAGER=''
export AWS_EC2_METADATA_DISABLED=true
files=()
while IFS=$'\t' read -r database file size hash; do
  [[ "$database" =~ ^[A-Za-z_][A-Za-z0-9_]{0,127}$ && "$file" == "${database}.bak" ]] || fail 'invalid archive name'
  [[ "$size" =~ ^[0-9]+$ && "$hash" =~ ^[0-9a-f]{64}$ ]] || fail 'invalid archive metadata'
  archive="${run_dir}/${file}"
  [[ -f "$archive" && ! -L "$archive" ]] || fail 'archive is missing or is a symbolic link'
  [[ "$(stat -c %s -- "$archive")" == "$size" ]] || fail 'archive size changed after backup'
  actual="$(sha256sum -- "$archive")"; actual="${actual%% *}"
  [[ "$actual" == "$hash" ]] || fail 'archive checksum changed after backup'
  aws "${endpoint_args[@]}" --region "$S3_REGION" s3 cp "$archive" "${target}/${file}" \
    --only-show-errors "${sse_args[@]}" --metadata "sha256=${hash}"
  files+=("$archive")
done < /work/files.tsv
(( ${#files[@]} > 0 )) || fail 'there are no completed archives'
# This object is the completion marker; incomplete runs have no manifest.
aws "${endpoint_args[@]}" --region "$S3_REGION" s3 cp /work/manifest.json "${target}/manifest.json" \
  --only-show-errors "${sse_args[@]}" --content-type application/json
date -u +%s > "/backup/.last-success-${run_id}"
mv -- "/backup/.last-success-${run_id}" /backup/.last-success
# Delete only validated files in this exact successful run. Preserve unrelated files.
for archive in "${files[@]}"; do rm -- "$archive"; done
rmdir -- "$run_dir"
printf 'S3 backup completed: %s\n' "$run_id"
