# Backup and Restore

The chart includes a CronJob-based backup system that uploads archives to S3-compatible storage.

## How It Works

The backup strategy is database-aware:

| Database | Tool | Archive Content |
|----------|------|-----------------|
| SQLite | `tar` | Full `/data` directory |
| PostgreSQL | `pg_dump` | SQL dump (gzipped) |
| MySQL | `mysqldump` | SQL dump (gzipped) |

After the dump, a MinIO client container uploads the archive to the configured S3 bucket.

## Enable Backups

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: my-backups
    prefix: answer
    accessKey: AKIAIOSFODNN7EXAMPLE
    secretKey: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

For production, use `backup.s3.existingSecret` instead of inline credentials.

## Restore

### SQLite

```bash
# Download the archive
mc cp backup/my-backups/answer/answer-sqlite-20260323T030000Z.tar.gz /tmp/

# Stop the deployment
kubectl scale deploy <release>-answer --replicas=0

# Extract into the PVC
kubectl cp /tmp/answer-sqlite-20260323T030000Z.tar.gz <pod>:/data/
kubectl exec <pod> -- tar -xzf /data/answer-sqlite-20260323T030000Z.tar.gz -C /data/

# Restart
kubectl scale deploy <release>-answer --replicas=1
```

### PostgreSQL

```bash
mc cp backup/my-backups/answer/answer-postgresql-20260323T030000Z.sql.gz /tmp/
gunzip /tmp/answer-postgresql-20260323T030000Z.sql.gz
psql -h <host> -U answer -d answer < /tmp/answer-postgresql-20260323T030000Z.sql
```

### MySQL

```bash
mc cp backup/my-backups/answer/answer-mysql-20260323T030000Z.sql.gz /tmp/
gunzip /tmp/answer-mysql-20260323T030000Z.sql.gz
mysql -h <host> -u answer -p answer < /tmp/answer-mysql-20260323T030000Z.sql
```

<!-- @AI-METADATA
type: chart-docs
title: Backup and Restore
description: S3 backup strategy and restore procedures for the Apache Answer Helm chart

keywords: backup, restore, s3, cronjob, sqlite, postgresql, mysql, minio

purpose: Help operators configure and use the backup system
scope: Chart

relations:
  - charts/answer/README.md
  - charts/answer/values.yaml
  - charts/answer/docs/database.md
path: charts/answer/docs/backup.md
version: 1.0
date: 2026-03-23
-->
