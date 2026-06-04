<!-- SPDX-License-Identifier: Apache-2.0 -->
# Wallabag — Backup & Restore

The wallabag database (PostgreSQL) is the source of truth — the PVC only holds
re-downloadable article assets. Back up the database.

## Scheduled backups (CronJob)

Enable the bundled backup CronJob to `pg_dump` to S3-compatible storage:

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"   # daily 03:00 UTC
  # S3 destination + credentials — see values.yaml backup.* for the full set
```

Each run dumps the wallabag database and uploads it to the configured bucket.
Inspect runs:

```bash
kubectl get cronjob,job -l app.kubernetes.io/instance=<release>
kubectl logs job/<backup-job> -n <namespace>
```

## Restore

1. Scale wallabag down (avoid writes during restore):

   ```bash
   kubectl scale deploy/<release>-wallabag --replicas=0
   ```

2. Restore the dump into PostgreSQL (bundled or external):

   ```bash
   # download dump from S3, then:
   psql -h <pg-host> -U wallabag -d wallabag < wallabag-dump.sql
   ```

3. Scale wallabag back up:

   ```bash
   kubectl scale deploy/<release>-wallabag --replicas=1
   ```

Article assets on the PVC are re-downloadable; the database restore is what
recovers your saved entries, tags and annotations.
