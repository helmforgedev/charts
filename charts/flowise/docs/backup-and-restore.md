<!-- SPDX-License-Identifier: Apache-2.0 -->
# Flowise backup and restore

The built-in CronJob backs up PostgreSQL to S3-compatible object storage. It
does not back up SQLite or external object-storage contents.

## Enable PostgreSQL backups

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  database:
    pgDumpArgs:
      - --no-owner
      - --no-acl
  s3:
    endpoint: https://s3.example.com
    bucket: platform-backups
    prefix: flowise
    existingSecret: flowise-backup-s3
```

The S3 Secret must contain `access-key` and `secret-key` unless key names are
overridden. Each `pgDumpArgs` item is passed directly to `pg_dump`; shell
expansion is not used.

## Verify a backup

Create an ad-hoc Job from the CronJob and inspect the result:

```bash
kubectl create job --from=cronjob/flowise-backup flowise-backup-manual
kubectl logs job/flowise-backup-manual --all-containers
```

Verify the uploaded object independently with the object-storage provider.
Retention, versioning, encryption, and cross-region replication are provider
responsibilities.

## Restore

Restoration is intentionally manual. Scale Flowise main and worker Deployments
to zero, download and decompress the selected dump, restore it into an empty or
approved PostgreSQL database with `psql`, then scale Flowise back up. Confirm the
application version is compatible with the restored schema and test login,
chatflows, credentials, and queue processing before reopening traffic.

Standalone SQLite installations should snapshot or copy the PVC while Flowise
is stopped. S3-backed installations also require an independent backup policy
for objects referenced by the database.
