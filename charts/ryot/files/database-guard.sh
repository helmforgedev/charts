#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -eu
umask 077
deadline=$(($(date +%s) + DATABASE_CONNECTION_TIMEOUT))
until psql -XAt -v ON_ERROR_STOP=1 -c 'SELECT 1' >/dev/null 2>&1; do
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo 'PostgreSQL did not accept an authenticated connection before the deadline' >&2
    exit 1
  fi
  sleep 1
done
table_exists=$(psql -XAt -v ON_ERROR_STOP=1 -c "SELECT to_regclass('\"user\"') IS NOT NULL")
if [ "$table_exists" = f ]; then
  printf true > /bootstrap-state/fresh
  echo 'New database: native migrations and protected initialization will follow'
  exit 0
fi
oidc_count=$(psql -XAt -v ON_ERROR_STOP=1 -c 'SELECT count(*) FROM "user" WHERE oidc_issuer_id IS NOT NULL')
if [ "$oidc_count" != 0 ]; then
  echo 'This local-authentication deployment cannot start with OIDC-linked accounts; remediate the restored database separately' >&2
  exit 1
fi
user_count=$(psql -XAt -v ON_ERROR_STOP=1 -c 'SELECT count(*) FROM "user"')
if [ "$user_count" = 0 ]; then printf true > /bootstrap-state/fresh; else printf false > /bootstrap-state/fresh; fi
echo 'Existing local-account database inspected without modifying users'
