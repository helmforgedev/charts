# Backup

The chart includes a CronJob that dumps the Guacamole database and uploads it to an S3-compatible bucket.

## Enable Backup

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: my-backups
    prefix: guacamole
    accessKey: AKIA...
    secretKey: ...
```

## Using an Existing Secret

```yaml
backup:
  enabled: true
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: my-backups
    existingSecret: my-s3-credentials
```

The secret must contain `access-key` and `secret-key` keys.

## How It Works

- **PostgreSQL**: uses `pg_dump` with `--clean --if-exists`
- **MySQL**: uses `mysqldump` with `--single-transaction --quick`
- Dumps are compressed with gzip and uploaded via `minio/mc`
- Archives are named `<archivePrefix>-<timestamp>.sql.gz`

<!-- @AI-METADATA
type: chart-docs
title: Guacamole Backup
description: Backup configuration for Guacamole chart using CronJob and S3
keywords: guacamole, backup, s3, cronjob, postgresql, mysql
purpose: Document backup setup and restore procedures
scope: Chart
relations:
  - charts/guacamole/README.md
  - charts/guacamole/values.yaml
path: charts/guacamole/docs/backup.md
version: 1.0
date: 2026-03-23
-->
