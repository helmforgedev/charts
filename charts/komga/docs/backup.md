# Backup

Komga stores its database and configuration in `/config`. The built-in backup CronJob exports each SQLite database with `VACUUM INTO`, copies the top-level application config files, optionally includes logs, and uploads the resulting archive to an S3-compatible bucket.

## Enable Backup

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: my-backups
    prefix: komga
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

1. The init container installs `sqlite3` if needed and exports each SQLite database found in `/config` using `VACUUM INTO`
2. It copies the top-level application config files, and optionally `/config/logs`
3. It creates a tar.gz archive named `<archivePrefix>-<timestamp>.tar.gz`
4. The upload container (`minio/mc`) sends the archive to the configured S3 bucket

Search indexes are not included because Komga will rebuild them when missing.

## Restore

1. Download the archive from S3
2. Extract to a local directory
3. Restore the exported database files back into `/config`
4. Restore the copied application config files, and logs if you backed them up
5. Start Komga and allow it to rebuild any missing search index data

<!-- @AI-METADATA
type: chart-docs
title: Komga Backup
description: Backup configuration for Komga chart using CronJob and S3
keywords: komga, backup, s3, cronjob, sqlite
purpose: Document backup setup and restore procedures
scope: Chart
relations:
  - charts/komga/README.md
  - charts/komga/values.yaml
path: charts/komga/docs/backup.md
version: 1.0
date: 2026-03-23
-->
