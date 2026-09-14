# Backup and restore

## What a backup contains

Each completed backup contains a PostgreSQL custom-format dump, the complete
application PVC archive, version manifest and SHA-256 checksums. This includes
users, shares, file identities, configuration, instance secrets, custom apps,
themes and files. Keep externally managed Kubernetes Secrets or provider records
separately, especially administrator, SMTP and storage credentials.

Use a private S3 bucket with TLS, encryption at rest, versioning and an appropriate
retention policy. The archive contains sensitive instance configuration and user
content. The bucket must exist before a Job runs. The backup principal needs
bucket listing and object read/write in the configured prefix. Avoid sharing the
backup bucket with public application content.

```yaml
backup:
  enabled: true
  schedule: "0 2 * * *"
  s3:
    bucket: company-nextcloud-backups
    prefix: production
    region: us-east-1
    existingSecret: nextcloud-backup-storage
```

The Secret contains `access-key` and `secret-key`. An optional `endpoint` supports
S3-compatible services. The default SQL client is PostgreSQL 18; use a matching
official client image for an external server. Allocate enough `workspaceSize`
and node ephemeral storage for the full archive and SQL dump.

## Availability and concurrency

Every backup stops both web and cron during SQL/file capture. Users experience
an outage proportional to the data size. Upload occurs after the application
resumes. Do not run Helm upgrades, manual scaling, database maintenance or
GitOps reconciliation during a backup. Configure a maintenance window and monitor
failed Jobs. The volume lock also prevents new application initialization while
the snapshot is in progress.

The default Pod grace period is 120 seconds and backup quiescence timeout is
180 seconds. Increase both for long-running uploads or background jobs, keeping
the quiescence timeout longer than the Pod grace period. If a process is forcibly
killed, its graceful-shutdown record is absent and the backup refuses to capture
state. Retrying after the long-running job finishes is safer than weakening this
check. The default first cron run is delayed five minutes after startup, matching
upstream timer guidance.

`concurrencyPolicy: Forbid` serializes scheduled runs, and an atomic volume lock
also rejects overlapping manually created Jobs. A failed lock owner is not
automatically evicted: operators must investigate before clearing it.

```bash
kubectl -n nextcloud create job nextcloud-backup-manual \
  --from=cronjob/nextcloud-backup
kubectl -n nextcloud get pods -l job-name=nextcloud-backup-manual
kubectl -n nextcloud logs job/nextcloud-backup-manual -c quiesce
kubectl -n nextcloud logs job/nextcloud-backup-manual -c archive-and-resume
kubectl -n nextcloud logs job/nextcloud-backup-manual -c upload
```

Use the actual full release resource name if it differs from `nextcloud`.
The upload log reports the exact unique S3 prefix. A prefix without `COMPLETE`
is incomplete and must not be used for restoration. Monitor Job success and the
age of the latest completed backup; a suspended schedule produces no new backups.

## Failed snapshot recovery

Inspect the failing init container and stop the failed/manual backup Job before
recovery. Confirm that no other backup is active. If the failure happened before
archive completion, the application may remain at zero replicas and the PVC may
contain `.helmforge-backup-lock`. Mount that PVC in an approved maintenance Pod,
inspect its `owner` and `quiesced` files, and remove only that lock directory after
confirming that its owner has stopped. Scale the application back to one replica
and verify `/status.php`, CLI status and a WebDAV operation. Do not remove any
application files or database objects. Investigate the snapshot failure before
resuming the schedule.

If upload failed, the application has already resumed; inspect credentials,
bucket permissions, endpoint and node storage. The failed prefix remains
incomplete and can be expired by a bucket lifecycle rule. A new backup creates a
new prefix rather than overwriting it.

## Restore to fresh storage

Use the exact application version of the backup. Prepare the original
administrator credential Secret and destination S3 credential Secret in the new
namespace. Provision an empty PostgreSQL database or let the bundled subchart
create one. Use a fresh application PVC. Never point the restore Job at a live
instance or populated database.

```yaml
nextcloud:
  existingSecret: original-nextcloud-admin
  trustedDomains: [cloud.example.com]
  overwriteCliUrl: https://cloud.example.com
restore:
  enabled: true
  backupPath: production/20260914T020000Z-unique-backup-id
backup:
  enabled: false
  s3:
    bucket: company-nextcloud-backups
    region: us-east-1
    existingSecret: nextcloud-backup-storage
```

Install with these values and wait for `<fullname>-restore` to complete. The
application deliberately has zero replicas during restoration. The Job checks
checksums and application version before extraction and refuses a nonempty PVC
or database. A failed restore must be diagnosed and retried on fresh storage;
do not bypass these safeguards to overwrite partial state.

After success, set `restore.enabled: false` using the same remaining values and
upgrade the release. Verify native CLI status, a non-admin login, WebDAV file
contents and file IDs, existing shares, application settings and a new write.
The chart reconciles the destination database endpoint and credentials while
retaining Nextcloud's native instance identity. Changing the bootstrap password
value does not reset the restored administrator account password.

## Upgrade rollback

Take and test a completed backup before upgrading. Helm rollback does not undo
Nextcloud database migrations. Recover by restoring the coherent pre-upgrade
backup into fresh storage with its original application version.
