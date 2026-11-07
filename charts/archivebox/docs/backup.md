# ArchiveBox Backup Guide

## Scope

The `archivebox` chart can create scheduled backups of the ArchiveBox `/data`
directory and upload them to S3-compatible object storage. It includes the
SQLite files when used, configuration, Personas, local indexes, and captured
artifacts. It does not back up an external PostgreSQL database.

A live tar archive is not a transaction-consistent database backup. The CronJob
does not pause ArchiveBox or use the SQLite backup API. Quiet traffic or a
read-only backup mount does not guarantee consistency.

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

For a recoverable SQLite backup, stop the ArchiveBox workload for the whole
archive operation or use a separately managed application-consistent snapshot
workflow. Merely scheduling a low-traffic period is insufficient. Ensure the
backup Pod can mount the data PVC under the storage class's access and node
affinity constraints.

With PostgreSQL, back up the database separately using PostgreSQL-aware tooling
and coordinate it with the filesystem backup while writes are stopped. Retain
both parts of the same recovery point. The chart does not create or schedule a
PostgreSQL backup job.

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

1. Stop the ArchiveBox deployment and any other capture or CLI writers.
2. Restore the backup tarball into the target `/data` volume.
3. If using PostgreSQL, restore the matching database backup and verify its
   connection Secret and database settings.
4. Ensure the intended non-root collection identity can read and write the
   restored files. Configure `archivebox.puid` / `archivebox.pgid` if the
   storage system requires a fixed identity.
5. Start one ArchiveBox deployment using a compatible application version.
6. Confirm login, snapshot listing, representative saved outputs, and search
   work before returning the service to users.

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

