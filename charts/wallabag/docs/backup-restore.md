<!-- SPDX-License-Identifier: Apache-2.0 -->
# Wallabag Backup and Restore

PostgreSQL holds every entry, tag, annotation, user, and setting. The PVC holds
downloaded article images, which Wallabag fetches again when an entry is
reloaded and the source page is still available. Back up the database.

## Scheduled backups

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.example.com
    bucket: wallabag-backups
    prefix: daily
    existingSecret: wallabag-backup-s3
    existingSecretAccessKeyKey: access-key
    existingSecretSecretKeyKey: secret-key
```

Each run writes `<archivePrefix>-postgresql-<UTC timestamp>.sql.gz` with
`pg_dump` and uploads it to `s3://<bucket>/<prefix>/` with the MinIO client.
Rendering fails when the endpoint, bucket, or credentials are missing.

Run a backup immediately and follow it:

```bash
kubectl create job --from=cronjob/<release>-wallabag-backup <release>-wallabag-backup-manual
kubectl logs job/<release>-wallabag-backup-manual -c postgres-backup
kubectl logs job/<release>-wallabag-backup-manual -c upload
```

## Restore

1. Stop Wallabag so nothing writes during the restore:

   ```bash
   kubectl scale deploy/<release>-wallabag --replicas=0
   ```

2. Download the archive and restore it into an empty `public` schema. The
   setup container already created the schema on first start, so drop it first:

   ```bash
   psql -h <pg-host> -U wallabag -d wallabag \
     -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'
   gunzip -c wallabag-postgresql-<timestamp>.sql.gz | psql -h <pg-host> -U wallabag -d wallabag
   ```

3. Start Wallabag again. The setup container finds the restored schema and only
   applies migrations that are newer than the backup:

   ```bash
   kubectl scale deploy/<release>-wallabag --replicas=1
   ```

The restored database keeps its own users and passwords; the chart's admin
settings are not applied to it.
