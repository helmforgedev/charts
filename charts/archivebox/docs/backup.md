# ArchiveBox Backup Guide

## Scope

The `archivebox` chart can create scheduled backups of the ArchiveBox `/data`
directory and upload them to S3-compatible object storage. This protects the
SQLite database and archived snapshot files together.

The backup feature is optional and disabled by default.

## Enabling Backups

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  archivePrefix: archivebox
  s3:
    endpoint: https://s3.example.com
    bucket: archivebox-backups
    prefix: daily
    existingSecret: archivebox-s3
```

The referenced Secret must contain the access key and secret key using the
configured key names:

```yaml
backup:
  s3:
    existingSecretAccessKeyKey: access-key
    existingSecretSecretKeyKey: secret-key
```

## Inline Credentials

Inline credentials are supported for development and CI scenarios:

```yaml
backup:
  enabled: true
  s3:
    endpoint: http://minio.minio.svc:9000
    bucket: archivebox-backups
    accessKey: minioadmin
    secretKey: minioadmin
```

For production, prefer `backup.s3.existingSecret`.

## CronJob Behavior

The CronJob uses two containers:

- `data-backup` creates a compressed archive from `/data`.
- `upload` uploads the archive to object storage with MinIO Client.

The generated object name includes a UTC timestamp:

```text
archivebox-data-YYYYMMDDTHHMMSSZ.tar.gz
```

The upload path is:

```text
s3://<bucket>/<prefix>/<archive>
```

## Scheduling Guidance

ArchiveBox uses SQLite and a file-backed data directory. Schedule backups during
periods of low archive activity to reduce the chance of capturing a busy
database.

Recommended production settings:

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  concurrencyPolicy: Forbid
  backoffLimit: 1
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
```

## Restore Guidance

The chart does not automate restore. A manual restore should:

1. Scale the ArchiveBox deployment down or stop writes.
2. Restore the backup tarball into the target `/data` volume.
3. Verify file ownership matches the runtime UID/GID.
4. Scale the deployment back up.
5. Confirm the web UI and snapshot listing are healthy.

Always test this process in a non-production namespace before relying on the
backup pipeline.

## Troubleshooting

Check CronJob status:

```bash
kubectl get cronjob -n <namespace> <release>-archivebox-backup
```

Check recent jobs:

```bash
kubectl get jobs -n <namespace> \
  -l app.kubernetes.io/instance=<release>
```

View backup logs:

```bash
kubectl logs -n <namespace> job/<backup-job-name> --all-containers
```

Common causes of backup failure:

- S3 endpoint is unreachable from the cluster.
- Bucket name or prefix is incorrect.
- Credentials do not allow bucket creation or object upload.
- PVC is not available to the backup job.
- ArchiveBox data volume is too large for the backup time window.
