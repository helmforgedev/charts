#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -eu
export PGOPTIONS='-c default_transaction_read_only=on'
psql -X -v ON_ERROR_STOP=1 <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'citext') OR to_regtype('citext') IS NULL THEN
    RAISE EXCEPTION 'DBA must install citext in the application search_path before Pocket ID migrations';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
    RAISE EXCEPTION 'DBA must install pgcrypto before the native Francis actor migrations';
  END IF;
  IF NOT has_schema_privilege(current_user, 'public', 'USAGE') OR NOT has_schema_privilege(current_user, 'public', 'CREATE') THEN
    RAISE EXCEPTION 'Pocket ID requires USAGE and CREATE on the public schema';
  END IF;
  IF to_regclass('public.schema_migrations') IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM public.schema_migrations WHERE dirty) THEN
      RAISE EXCEPTION 'Pocket ID migration state is dirty; inspect and repair manually before restarting';
    END IF;
  END IF;
END $$;
SQL
printf '%s\n' 'PostgreSQL extension, schema privileges and migration state verified without writes'
