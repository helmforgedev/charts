# Memos Backup and Restore

## What to Back Up

Always back up the PersistentVolumeClaim mounted at `persistence.mountPath`.

SQLite mode:

- SQLite database
- local assets
- instance data
- initial administrator and provisioning Secrets, preserved separately from the PVC

External database mode:

- external MySQL/PostgreSQL database
- PVC contents for local assets and instance data

## SQLite Backup

For small instances, stop writes before taking a snapshot or file copy. Storage-level snapshots are preferred when
available.

```bash
kubectl scale statefulset memos-memos --replicas=0
# take a PVC snapshot or copy the volume contents
kubectl scale statefulset memos-memos --replicas=1
```

If downtime is not acceptable, use a CSI snapshot mechanism that provides crash-consistent or application-consistent
snapshots according to your storage backend.

Wait for the writer pod to terminate before archiving. Include the complete directory, with SQLite WAL files and assets;
copying only a live `memos_prod.db` can lose committed state. Preserve the original `persistence.mountPath` on recovery.
The runtime recovery profile archives all top-level state entries and restores them into a fresh PVC, then verifies the
same private memo, exact attachment bytes and persisted refresh-token identity.

## External Database Backup

Back up the database with native tooling such as `pg_dump` or `mysqldump`, then back up the PVC separately.

Coordinate application writes so database references and original assets represent the same recovery point. Bundled
database charts expose their own native backup options; configure storage and retention explicitly. S3 storage also
needs matching bucket objects, database state and the native provisioning Secret. A database dump alone does not include
S3 objects or locally stored attachments.

## Restore Order

1. Restore or recreate the PVC contents.
2. Restore the external database, if used.
3. Recreate the DSN Secret.
4. Install or upgrade the chart with the same `database.driver` and `persistence.mountPath`.
5. Watch logs for migrations and startup errors.

Set `persistence.existingClaim` to the recovered volume. When converting an existing StatefulSet from generated claim
templates to an existing claim, Kubernetes requires recreating the stopped controller because claim templates are
immutable. Preserve both old and recovered PVCs, recreate the controller through Helm, and verify native login, memo
content, original checksums and search before reopening access. Never delete the source volume as part of this
operation. Helm rollback does not reverse database migrations.
