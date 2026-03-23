---
title: WordPress Backup & Restore
description: S3 backup strategy and restore procedures for WordPress on Kubernetes
keywords: [wordpress, backup, restore, s3, mysqldump, minio]
scope: chart-docs
audience: users, operators
---

# Backup & Restore

The chart includes a CronJob-based backup system that creates database dumps and wp-content archives, then uploads both to S3-compatible storage.

## How It Works

```
CronJob (scheduled)
├── Init 1: mysqldump → database dump (.sql.gz)
├── Init 2: tar wp-content → content archive (.tar.gz)
└── Main: minio/mc upload both to S3
```

1. **dump-database** (init container, `mysql:8.4`): Runs `mysqldump` against the database, compresses with gzip
2. **archive-content** (init container, `alpine:3.22`): Creates a tar.gz archive of `/var/www/html/wp-content` (themes, plugins, uploads)
3. **upload** (main container, `minio/mc`): Uploads both files to the configured S3 bucket

## Enabling Backup

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: wordpress-backups
    prefix: wordpress
    accessKey: "your-access-key"
    secretKey: "your-secret-key"
```

With existing secrets:

```yaml
backup:
  enabled: true
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: wordpress-backups
    existingSecret: wordpress-s3
```

The secret must contain `access-key` and `secret-key` keys.

## Database Credential Overrides

By default, the backup uses the same database credentials as the application. To use a read-only user for backups:

```yaml
backup:
  database:
    host: db-replica.example.com
    username: backup-user
    password: backup-password
    mysqldumpArgs: "--single-transaction --quick --skip-lock-tables"
```

## Restore Procedure

### Database Restore

```bash
# Download the backup from S3
mc cp backup/wordpress-backups/wordpress/wordpress-db-20260323-030000.sql.gz ./

# Decompress
gunzip wordpress-db-20260323-030000.sql.gz

# Restore to the database
kubectl exec -i <mysql-pod> -- mysql -u wordpress -p wordpress < wordpress-db-20260323-030000.sql
```

### Content Restore

```bash
# Download the content backup
mc cp backup/wordpress-backups/wordpress/wordpress-content-20260323-030000.tar.gz ./

# Copy to the WordPress pod
kubectl cp wordpress-content-20260323-030000.tar.gz <wordpress-pod>:/tmp/

# Extract in the pod
kubectl exec <wordpress-pod> -- tar -C /var/www/html -xzf /tmp/wordpress-content-20260323-030000.tar.gz
```

## S3-Compatible Storage

The backup works with any S3-compatible storage:

- **AWS S3**: `endpoint: https://s3.amazonaws.com`
- **MinIO**: `endpoint: https://minio.example.com`
- **DigitalOcean Spaces**: `endpoint: https://nyc3.digitaloceanspaces.com`
- **Backblaze B2**: `endpoint: https://s3.us-west-000.backblazeb2.com`

<!-- @AI-METADATA
type: chart-docs
title: WordPress Backup & Restore
description: S3 backup strategy and restore procedures for WordPress on Kubernetes
keywords: wordpress, backup, restore, s3, mysqldump, minio
purpose: Backup and restore guide for the wordpress Helm chart
scope: Chart
relations:
  - charts/wordpress/README.md
  - charts/wordpress/values.yaml
path: charts/wordpress/docs/backup.md
version: 1.0
date: 2026-03-23
-->
