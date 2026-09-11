#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Operator helper: run in the official SQL Server image after downloading and verifying an archive.
set -euo pipefail
umask 077
fail() { printf 'Restore refused: %s\n' "$1" >&2; exit 1; }
[[ -n ${SQL_HOST:-} && -n ${SQLCMDUSER:-} && -n ${SQLCMDPASSWORD:-} ]] || fail 'privileged recovery credentials are required'
[[ ${SQL_PORT:-1433} =~ ^[0-9]+$ ]] || fail 'invalid SQL port'
for name in "${RESTORE_DATABASE:-}" "${RESTORE_DATA_LOGICAL_NAME:-}" "${RESTORE_LOG_LOGICAL_NAME:-}"; do
  [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]{0,127}$ ]] || fail 'database and logical file names must use the documented ASCII identifier subset'
done
[[ "$RESTORE_DATA_LOGICAL_NAME" != "$RESTORE_LOG_LOGICAL_NAME" ]] || fail 'data and log logical names must differ'
[[ ${RESTORE_FILE:-} =~ ^/backup/[A-Za-z0-9_/-]+\.bak$ && "$RESTORE_FILE" != *'..'* ]] || fail 'archive must be a safe server-visible path under /backup'
case "${RESTORE_DATABASE,,}" in master|model|msdb|tempdb) fail 'system database restore is not supported by this helper';; esac
sqlcmd=/opt/mssql-tools18/bin/sqlcmd
[[ -x "$sqlcmd" ]] || fail 'the official image must provide sqlcmd tools18'
# No REPLACE is used. Existing databases are explicitly refused before RESTORE.
"$sqlcmd" -S "tcp:${SQL_HOST},${SQL_PORT:-1433}" -U "$SQLCMDUSER" -N -b -V 11 -r 1 -x -l 30 -t 0 <<SQL
IF DB_ID(N'${RESTORE_DATABASE}') IS NOT NULL
  THROW 51000, 'Restore target already exists; select a new database name.', 1;
RESTORE VERIFYONLY FROM DISK = N'${RESTORE_FILE}' WITH CHECKSUM;
RESTORE DATABASE [${RESTORE_DATABASE}] FROM DISK = N'${RESTORE_FILE}'
WITH CHECKSUM, RECOVERY,
MOVE N'${RESTORE_DATA_LOGICAL_NAME}' TO N'/var/opt/mssql/data/${RESTORE_DATABASE}.mdf',
MOVE N'${RESTORE_LOG_LOGICAL_NAME}' TO N'/var/opt/mssql/data/${RESTORE_DATABASE}_log.ldf';
DBCC CHECKDB ([${RESTORE_DATABASE}]) WITH NO_INFOMSGS;
GO
SQL
printf 'Restore and integrity check completed: %s\n' "$RESTORE_DATABASE"
