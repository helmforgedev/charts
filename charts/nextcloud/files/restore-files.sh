#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
php -r 'require "/usr/src/nextcloud/version.php";$m=json_decode(file_get_contents("/work/manifest.json"),true,512,JSON_THROW_ON_ERROR);if($m["formatVersion"]!==1||$m["appVersion"]!==$OC_VersionString)throw new RuntimeException("Restore requires the matching Nextcloud application version and backup format");'
if find /var/www/html -mindepth 1 -maxdepth 1 ! -name lost+found -print -quit | grep -q .; then
  echo 'Restore requires a fresh empty application PVC' >&2
  exit 1
fi
tar --no-same-owner --no-same-permissions -xzf /work/files.tar.gz -C /var/www/html
test -s /var/www/html/config/config.php
echo 'Application files restored; database restoration follows'
