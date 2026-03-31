---
title: Velero - S3-Compatible Storage
description: Configure Velero with S3-compatible object storage such as MinIO
keywords: [velero, s3, minio, backupstoragelocation]
scope: chart-docs
audience: users
---

# S3-Compatible Storage

This chart is intentionally optimized for S3-compatible object storage in v1.

Typical providers:

- MinIO
- Ceph RGW
- Cloudian
- other providers that expose the AWS S3 API contract

## Recommended baseline

Use:

- the default AWS plugin
- an explicit `s3Url`
- `s3ForcePathStyle=true` when the provider requires path-style addressing

## Example

```yaml
credentials:
  secretContents: |
    [default]
    aws_access_key_id=minioadmin
    aws_secret_access_key=minioadmin123

configuration:
  backupStorageLocations:
    - name: default
      provider: aws
      bucket: velero
      default: true
      config:
        region: minio
        s3Url: http://minio.minio.svc.cluster.local:9000
        s3ForcePathStyle: true
        insecureSkipTLSVerify: true
```

## Validation checklist

- confirm credentials are mounted at `/credentials/cloud`
- confirm the `BackupStorageLocation` reaches `Available`
- validate a test backup before enabling recurring schedules

<!-- @AI-METADATA
type: chart-docs
title: Velero - S3-Compatible Storage
description: Configure Velero with S3-compatible object storage such as MinIO

keywords: velero, s3, minio, backupstoragelocation

purpose: Guide operators through S3-compatible object storage setup for Velero
scope: Chart Architecture

relations:
  - charts/velero/README.md
  - charts/velero/docs/filesystem-backup.md
path: charts/velero/docs/s3-compatible.md
version: 1.0
date: 2026-03-31
-->
