# Memos Backup and Restore

## What to Back Up

Always back up the PersistentVolumeClaim mounted at `persistence.mountPath`.

SQLite mode:

- SQLite database
- local assets
- instance data

External database mode:

- external MySQL/PostgreSQL database
- PVC contents for local assets and instance data

## SQLite Backup

For small instances, stop writes before taking a snapshot or file copy. Storage-level snapshots are preferred when available.

```bash
kubectl scale statefulset memos --replicas=0
# take a PVC snapshot or copy the volume contents
kubectl scale statefulset memos --replicas=1
```

If downtime is not acceptable, use a CSI snapshot mechanism that provides crash-consistent or application-consistent snapshots according to your storage backend.

## External Database Backup

Back up the database with native tooling such as `pg_dump` or `mysqldump`, then back up the PVC separately.

## Restore Order

1. Restore or recreate the PVC contents.
2. Restore the external database, if used.
3. Recreate the DSN Secret.
4. Install or upgrade the chart with the same `database.driver` and `persistence.mountPath`.
5. Watch logs for migrations and startup errors.
