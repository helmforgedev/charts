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

## Using Workload Identity

Use ambient credentials from the backup pod on platforms such as Amazon EKS.
No static S3 credential Secret is rendered or referenced in this mode.

```yaml
backup:
  enabled: true
  serviceAccount:
    create: true
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/guacamole-backup
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: my-backups
    region: us-east-1
    credentialsFromPodIdentity: true
```

Set `backup.serviceAccount.create: false` and provide
`backup.serviceAccount.name` to reuse an existing identity-enabled account.

## How It Works

- **PostgreSQL**: uses `pg_dump` with `--clean --if-exists`
- **MySQL**: uses `mysqldump` with `--single-transaction --quick`
- Dumps are compressed with gzip and uploaded via the HelmForge `mc` image
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
