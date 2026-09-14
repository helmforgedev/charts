#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
export HOME=/tmp AWS_CONFIG_FILE=/tmp/aws-config AWS_SHARED_CREDENTIALS_FILE=/tmp/aws-credentials AWS_EC2_METADATA_DISABLED=true
export AWS_DEFAULT_REGION="$S3_REGION"
aws configure set default.s3.addressing_style path
aws configure set default.s3.max_concurrent_requests 2
endpoint=()
if [ -n "$S3_ENDPOINT" ]; then endpoint=(--endpoint-url "$S3_ENDPOINT"); fi
if [ "$1" = preflight ]; then
  aws "${endpoint[@]}" s3api head-bucket --bucket "$S3_BUCKET"
elif [ "$1" = upload ]; then
  cd /work
  sha256sum -c COMPLETE
  sha256sum -c SHA256SUMS
  destination="s3://${S3_BUCKET}/${S3_PREFIX}/$(cat backup-id)"
  for file in manifest.json database.dump files.tar.gz SHA256SUMS; do
    aws "${endpoint[@]}" s3 cp "$file" "${destination}/${file}" --only-show-errors
  done
  # Consumers must ignore backup prefixes without this final commit marker.
  aws "${endpoint[@]}" s3 cp COMPLETE "${destination}/COMPLETE" --only-show-errors
  echo "Completed backup: ${destination}"
elif [ "$1" = download ]; then
  cd /work
  for file in COMPLETE SHA256SUMS manifest.json database.dump files.tar.gz; do
    aws "${endpoint[@]}" s3 cp "s3://${S3_BUCKET}/${RESTORE_PATH}/${file}" "$file" --only-show-errors
  done
  sha256sum -c COMPLETE
  sha256sum -c SHA256SUMS
else
  echo 'Expected preflight, upload or download' >&2
  exit 1
fi
