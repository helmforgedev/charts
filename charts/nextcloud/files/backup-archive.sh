#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail
test -s /work/database.dump
test -f /var/www/html/.helmforge-backup-lock/quiesced
cd /var/www/html
# Exclude the PVC mount root so restoration never changes provider-owned metadata.
find . -mindepth 1 -maxdepth 1 ! -name .helmforge-backup-lock ! -name .helmforge-quiescence ! -name nextcloud-init-sync.lock ! -name lost+found -print0 |
  tar --null -T - -czf /work/files.tar.gz
php -r '
require "/var/www/html/version.php";
$manifest=["formatVersion"=>1,"appVersion"=>$OC_VersionString,"image"=>getenv("APP_IMAGE"),"databaseVersion"=>trim(file_get_contents("/work/database-version.txt")),"createdAt"=>gmdate(DATE_ATOM),"backupId"=>trim(file_get_contents("/work/backup-id"))];
file_put_contents("/work/manifest.json", json_encode($manifest,JSON_PRETTY_PRINT|JSON_THROW_ON_ERROR)."\n");'
cd /work
sha256sum manifest.json database.dump files.tar.gz > SHA256SUMS
sha256sum SHA256SUMS > COMPLETE
php /scripts/backup-coordinate.php resume
