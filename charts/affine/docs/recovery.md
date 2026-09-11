# Coordinated backup and restoration

The recovery unit comprises PostgreSQL, all application filesystem storage, the
complete configuration directory and referenced Secrets. This includes the exact
SEC1 `config/private.key` and database-managed signing/configuration records.
The generated configuration contains database credentials and must be protected
with the same care as other secrets.

Use a maintenance window to stop every application writer before taking the
database and filesystem snapshots. A consistent `pg_dump` alone does not coordinate
with files that are still changing. Retain the complete storage tree, including
avatars and any configured auxiliary storage, rather than selecting one known blob.

1. Record the chart/application image, dependency versions, values and Secret
   references. Suspend application traffic and background writers.
2. Take a checked PostgreSQL logical backup and archive or snapshot the entire
   application PVC. Protect and retain the matching Secrets separately.
3. Restore into an empty target database and a fresh application PVC. Have a DBA
   install `vector`; preserve the intended application-role ownership and privileges.
4. Restore configuration and storage with UID/GID 1000 and restrictive private-key
   permissions before allowing the application to start.
5. Point the release at the restored database and claim, then allow the pinned native
   migration sequence to complete. Diagnose migration failures explicitly.
6. Verify the original identity and private key, a native login, workspace permissions,
   exact blob bytes and a persisted document edit/reopen. Confirm the intended
   origin and integration endpoints before restoring public traffic.

The chart's dedicated `ci/restore-values.yaml` scenario quiesces the singleton,
uses `pg_dump`/`pg_restore` into a separate empty database, and copies the complete
private configuration/storage archive into a new PVC. The original database and PVC
remain separate from the restore target until disposable namespace cleanup. The
scenario passed with the original signing key and session, exact blob bytes, and
native document editing and reopening against the restored state.

The fixture preinstalls `vector` as DBA and excludes only that extension's creation
and comment entries from the restore list, so application objects are restored under
the application role with checked errors. Adapt ownership and extension handling to
the privileges of the target database; do not suppress arbitrary restore failures.

PVC retention protects against an accidental Helm uninstall; it is not a backup.
Configure off-cluster retention, encryption, access controls and restore rehearsals
for the actual storage platform. If native administrator configuration uses external
object storage, include all referenced objects and their matching database state in
the same recovery plan. No application-consistent live backup or automatic downgrade
is asserted by this chart.
