# Strapi Backup & Restore

The Strapi chart can run a scheduled CronJob that uploads backup artifacts to S3-compatible object storage.

## What Gets Backed Up

### SQLite mode

The backup archives the chart PVC contents, which includes:

- uploads data
- SQLite data directory

### PostgreSQL or MySQL mode

The backup creates:

- a SQL dump of the configured database
- an uploads archive when `persistence.enabled=true`

## Minimal Configuration

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: strapi-backups
    existingSecret: strapi-s3
```

The S3 secret must contain:

- `access-key`
- `secret-key`

## Inline Credentials

```yaml
backup:
  enabled: true
  s3:
    endpoint: https://minio.example.com
    bucket: strapi-backups
    accessKey: minio-access-key
    secretKey: minio-secret-key
```

## Database Override

Use the backup database override only when Strapi reads from one endpoint but you want dumps from another:

```yaml
backup:
  database:
    host: postgres-replica.example.com
    port: 5432
    name: strapi
    username: strapi
    existingSecret: strapi-db-backup
```

## Restore Notes

The chart does not automate restore. Recommended restore flow:

1. stop or scale down the Strapi deployment
2. restore uploads content to the PVC or replacement volume
3. restore the SQLite archive or import the SQL dump into PostgreSQL/MySQL
4. start Strapi again and validate the admin and public API

## Important Limits

- if your Strapi project uses external object storage for media, this chart backup only covers what is stored on the chart PVC
- if `persistence.enabled=false`, only the SQL dump is backed up in PostgreSQL/MySQL mode
- SQLite backups require `persistence.enabled=true`

<!-- @AI-METADATA
type: chart-docs
title: Strapi Backup & Restore
description: S3 backup strategy and restore considerations for Strapi uploads and database data

keywords: strapi, backup, restore, s3, sqlite, postgresql, mysql

purpose: Document backup scope, configuration, and restore considerations for the Strapi chart
scope: Chart

relations:
  - charts/strapi/README.md
  - charts/strapi/values.yaml
path: charts/strapi/docs/backup.md
version: 1.0
date: 2026-03-29
-->
