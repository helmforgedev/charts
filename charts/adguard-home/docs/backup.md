# AdGuard Home Backup

This chart includes an optional CronJob that creates tar archives of AdGuard Home data and uploads them to an S3-compatible storage backend.

## How It Works

1. An **init container** (busybox) creates a tar.gz archive of both `/opt/adguardhome/conf` and `/opt/adguardhome/work` directories
2. The **main container** (minio/mc) uploads the archive to the configured S3 bucket

## Enabling Backup

```yaml
backup:
  enabled: true
  schedule: "0 2 * * *"  # daily at 2 AM
  s3:
    endpoint: https://s3.us-east-1.amazonaws.com
    bucket: adguard-backups
    accessKey: AKIAIOSFODNN7EXAMPLE
    secretKey: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

## S3-Compatible Backends

The backup uses MinIO Client (`mc`), which supports any S3-compatible endpoint:

- **AWS S3**: `https://s3.<region>.amazonaws.com`
- **MinIO**: `https://minio.example.com`
- **Backblaze B2**: `https://s3.<region>.backblazeb2.com`
- **Cloudflare R2**: `https://<account-id>.r2.cloudflarestorage.com`

## Using an Existing Secret

```yaml
backup:
  enabled: true
  s3:
    endpoint: https://s3.us-east-1.amazonaws.com
    bucket: adguard-backups
    existingSecret: my-s3-credentials
    existingSecretAccessKeyKey: access-key
    existingSecretSecretKeyKey: secret-key
```

## Using IRSA

```yaml
backup:
  enabled: true
  serviceAccount:
    name: adguard-home-backup
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/adguard-home-backup
  s3:
    endpoint: https://s3.amazonaws.com
    region: us-east-1
    bucket: adguard-backups
    credentialsFromPodIdentity: true
```

The role needs the S3 permissions required to create the bucket when
`createBucketIfNotExists=true`, list it, and upload objects below the selected
prefix. Set `createBucketIfNotExists=false` when bucket creation is managed
outside the chart.

## Using EKS Pod Identity

EKS Pod Identity does not use a ServiceAccount annotation. Give the dedicated
ServiceAccount a stable name:

```yaml
backup:
  enabled: true
  serviceAccount:
    name: adguard-home-backup
  s3:
    endpoint: https://s3.amazonaws.com
    region: us-east-1
    bucket: adguard-backups
    credentialsFromPodIdentity: true
```

Install the EKS Pod Identity Agent unless the cluster uses EKS Auto Mode, then
create an AWS-side Pod Identity association that maps the IAM role to the
cluster, release namespace, and `adguard-home-backup` ServiceAccount.

The upload container uses the `mc` credential chain through the regional AWS
STS endpoint. Static credential environment variables and the chart-managed
backup Secret are omitted in workload identity mode.

## Archive Naming

Archives follow the pattern: `<archivePrefix>-<timestamp>.tar.gz`

Default prefix is `adguard-home`. Customize with:

```yaml
backup:
  archivePrefix: my-adguard
```

## Resources Generated

| Resource | Condition |
|----------|-----------|
| CronJob (`*-backup`) | `backup.enabled` |
| ConfigMap (`*-backup-scripts`) | `backup.enabled` |
| ServiceAccount (`*-backup`) | `backup.enabled` and `backup.serviceAccount.create` |
| Secret (`*-backup`) | `backup.enabled`, static credentials, and no `backup.s3.existingSecret` |

<!-- @AI-METADATA
type: chart-docs
title: AdGuard Home Backup
description: Automated S3 backups for AdGuard Home configuration and data
keywords: adguard, backup, s3, minio, cronjob, tar
purpose: Guide for enabling and configuring automated backups in the AdGuard Home chart
scope: Chart
relations:
  - charts/adguard-home/README.md
  - charts/adguard-home/values.yaml
path: charts/adguard-home/docs/backup.md
version: 1.0
date: 2026-03-23
-->
