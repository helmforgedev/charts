# Heimdall Backup

The backup CronJob archives the Heimdall `/config` directory and uploads it to
an S3-compatible bucket. This captures dashboard links, settings, and SQLite
state.

## Enable Backup

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: heimdall-backups
    prefix: heimdall
    existingSecret: heimdall-s3-credentials
```

The existing Secret must contain:

- `access-key`
- `secret-key`

Use custom key names when the platform Secret uses different fields:

```yaml
backup:
  s3:
    existingSecret: platform-s3
    existingSecretAccessKeyKey: AWS_ACCESS_KEY_ID
    existingSecretSecretKeyKey: AWS_SECRET_ACCESS_KEY
```

## Workload Identity

Use ambient cloud credentials instead of a Kubernetes Secret by enabling
workload identity. The chart creates a dedicated ServiceAccount for backup jobs;
attach the platform-specific identity annotation to it:

```yaml
backup:
  enabled: true
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/heimdall-backup
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: heimdall-backups
    region: us-east-1
    credentialsFromPodIdentity: true
```

When `credentialsFromPodIdentity` is enabled, static access keys and Secret
references are neither rendered nor consumed. Set `backup.serviceAccount.create`
to `false` and provide `backup.serviceAccount.name` to use an existing dedicated
ServiceAccount.

## Inline Test Credentials

Inline credentials create a chart-managed Secret and are intended for local
testing only:

```yaml
backup:
  enabled: true
  s3:
    endpoint: http://minio.minio.svc:9000
    bucket: heimdall
    accessKey: minio
    secretKey: minio123
```

## Restore Outline

1. Scale the Deployment to zero.
2. Download the desired archive from S3.
3. Extract it into the PVC mounted at `/config`.
4. Scale the Deployment back to one replica.
5. Confirm the dashboard loads and application links are present.

<!-- @AI-METADATA
type: chart-docs
title: Heimdall Backup
description: Backup and restore guidance for the Heimdall chart
keywords: heimdall, backup, s3, cronjob, restore
purpose: Document S3 backup and restore workflow for Heimdall
scope: Chart
relations:
  - charts/heimdall/README.md
  - charts/heimdall/templates/backup-cronjob.yaml
path: charts/heimdall/docs/backup.md
version: 1.0
date: 2026-11-14
-->
