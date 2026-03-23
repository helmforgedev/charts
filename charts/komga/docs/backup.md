# Backup

Komga stores its database and configuration in `/config`. The built-in backup CronJob creates a tar archive of this directory and uploads it to an S3-compatible bucket.

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

1. An init container (`alpine`) creates a tar.gz archive of `/config`
2. The main container (`minio/mc`) uploads the archive to the configured S3 bucket
3. Archives are named `<archivePrefix>-<timestamp>.tar.gz`

## Restore

1. Download the archive from S3
2. Extract to a local directory
3. Mount the directory as the `/config` volume or copy contents into the config PVC

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
