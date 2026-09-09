#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -u
mode="$1"
interval="$2"
child=''
stop() {
  trap '' TERM INT WINCH
  if [ -n "$child" ]; then
    kill -TERM "$child" 2>/dev/null || true
    wait "$child" 2>/dev/null || true
  fi
  exit 0
}
# The upstream Apache image declares SIGWINCH as its container stop signal.
trap stop TERM INT WINCH
while :; do
  started=$(date +%s)
  if [ "$mode" = adhoc ]; then
    php /var/www/html/admin/cli/adhoc_task.php --execute --keep-alive="$interval" &
  else
    php /var/www/html/admin/cli/cron.php --keep-alive=0 &
  fi
  child=$!
  if wait "$child"; then
    date +%s > /tmp/moodle-task-last-success
  else
    echo 'Moodle task command returned a nonzero exit status' >&2
  fi
  elapsed=$(( $(date +%s) - started ))
  delay=$(( interval - elapsed ))
  [ "$delay" -gt 0 ] || delay=1
  sleep "$delay" &
  child=$!
  wait "$child" || true
done
