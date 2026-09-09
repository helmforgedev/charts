#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -eu
umask 0027
if [ "$SOURCE_MODE" = archive ]; then
  curl --fail --location --silent --show-error --retry 3 --connect-timeout 15 \
    --max-time "$DOWNLOAD_TIMEOUT" --proto '=https' --proto-redir '=https' \
    "$SOURCE_URL" -o /tmp/moodle.tgz
  printf '%s  /tmp/moodle.tgz\n' "$SOURCE_SHA256" | sha256sum -c -
  tar --no-same-owner -xzf /tmp/moodle.tgz -C /var/www/html --strip-components=1
else
  cp -R "$SOURCE_IMAGE_PATH"/. /var/www/html/
fi
test -f /var/www/html/public/version.php
test -f /var/www/html/admin/cli/install_database.php
cp /opt/helmforge/config.php /var/www/html/config.php
echo 'Verified Moodle code prepared; web and task containers mount it read-only.'
