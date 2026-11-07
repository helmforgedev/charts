# ArchiveBox Backup Guide

## Scope

The `archivebox` chart can create scheduled archives of the ArchiveBox `/data`
directory and upload them to S3-compatible object storage. With SQLite, the
archive contains the database and snapshot files. With external PostgreSQL, it
contains only `/data`; it never creates a PostgreSQL dump.

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

## Workload Identity

AWS EKS Pod Identity and IRSA can avoid long-lived S3 keys:

```yaml
backup:
  enabled: true
  serviceAccount:
    create: true
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/archivebox-backup
  s3:
    endpoint: https://s3.us-east-1.amazonaws.com
    region: us-east-1
    bucket: archivebox-backups
    credentialsFromPodIdentity: true
```

The chart creates a dedicated backup ServiceAccount. When workload identity is
enabled, it does not create or mount static S3 credentials. EKS Pod Identity
requires an association for this ServiceAccount; IRSA requires its role ARN
annotation.

## CronJob Behavior

The CronJob uses two containers and does not stop the ArchiveBox Deployment:

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

Because the scheduled CronJob reads a live filesystem, it is not by itself an
application-consistent backup. For a recoverable maintenance backup, stop or
scale down ArchiveBox, create the `/data` archive, and then restart it.

With external PostgreSQL, retain a matching database dump and `/data` archive
from the same quiesced window. One possible sequence is:

```bash
kubectl scale deployment/<release>-archivebox --replicas=0
PGPASSWORD='<password>' pg_dump --format=custom \
  --host=<postgres-host> --username=<postgres-user> \
  --file=archivebox-postgresql.dump <postgres-database>
kubectl create job --from=cronjob/<release>-archivebox-backup \
  <release>-archivebox-backup-manual
kubectl wait --for=condition=complete job/<release>-archivebox-backup-manual \
  --timeout=30m
kubectl scale deployment/<release>-archivebox --replicas=1
```

Coordinate the commands through the platform's maintenance process. Never
restore a PostgreSQL dump and `/data` archive from unrelated points in time.

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
3. If using PostgreSQL, restore the matching `pg_dump` backup before restart.
4. Verify file ownership matches the runtime UID/GID.
5. Scale the deployment back up.
6. Confirm the web UI and snapshot listing are healthy.

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
