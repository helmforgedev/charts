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
if [ "$METRICS_ENABLED" = true ]; then
  plugin=/var/www/html/public/admin/tool/monitoring
  if [ "$METRICS_PLUGIN_MODE" = archive ]; then
    if [ -e "$plugin" ]; then
      echo 'Plugin already exists in application code; use metrics.plugin.mode=image.' >&2
      exit 1
    fi
    curl --fail --location --silent --show-error --retry 3 --connect-timeout 15 \
      --max-time "$DOWNLOAD_TIMEOUT" --proto '=https' --proto-redir '=https' \
      "$METRICS_PLUGIN_URL" -o /tmp/monitoring.tgz
    printf '%s  /tmp/monitoring.tgz\n' "$METRICS_PLUGIN_SHA256" | sha256sum -c -
    mkdir -p "$plugin"
    tar --no-same-owner -xzf /tmp/monitoring.tgz -C "$plugin" --strip-components=1
  fi
  test -f "$plugin/version.php"
  test -f "$plugin/exporter/prometheus/version.php"
fi
cp /opt/helmforge/config.php /var/www/html/config.php
echo 'Verified Moodle code prepared; web and task containers mount it read-only.'
