# Backup and recovery

The optional CronJob creates native full SQL Server backups and uploads them to S3-compatible storage. It works with Express because it uses
`BACKUP TO DISK`; SQL Server's native S3 URL backup is unavailable in Express. The schedule uses Kubernetes rather than SQL Agent.

## Configure production backups

Select an explicit list of existing databases. Names supported by the built-in scripts contain ASCII letters, digits and underscores,
beginning with a letter or underscore, and have at most 128 characters. The dedicated backup login receives `db_backupoperator` only in
those databases. Database creation and application privileges are separate concerns.

Configure a dedicated staging PVC shared by SQL Server and the backup Job. RWO requires both Pods on the same node; the chart's backup
affinity enforces this. ReadWriteOncePod cannot be shared between these Pods. The staging volume must fit the full selected backup set plus
failed runs awaiting operator cleanup. SQL Server consumes the claim at installation, including storage classes with delayed binding.

Use existing Secrets or External Secrets for passwords and S3 keys. For AWS workload identity, configure the backup ServiceAccount and trust
policy explicitly; a rendered role annotation is not evidence of a working IAM federation. The uploader supports standard AWS CLI credential
providers. The database ServiceAccount does not need access to S3.

Use an HTTPS endpoint and a trusted CA bundle for private certificate authorities. Production must not bypass certificate verification.
Scope S3 permissions to the configured bucket prefix and required upload/multipart operations. Configure optional SSE-S3 or SSE-KMS when the
storage service supports it; KMS also requires a suitable key policy and IAM permissions.

## What a successful run means

The SQL init container creates a unique directory under `/backup` and performs `BACKUP DATABASE` with `COPY_ONLY` and `CHECKSUM`.
Compression must remain disabled for editions that cannot create compressed backups, including Express and SQL Server 2022 Web.

The uploader validates each file's size and SHA-256 before upload. Objects are stored under `<prefix>/<run-id>/`. `manifest.json` is
published last and identifies the completed set:

```json
{
  "schemaVersion": 1,
  "runId": "mssql-20260911T120000Z-0123456789abcdef",
  "createdAt": "2026-09-11T12:00:00Z",
  "backupType": "full-copy-only",
  "checksum": true,
  "compression": false,
  "files": [
    {
      "database": "application",
      "file": "application.bak",
      "sizeBytes": 1048576,
      "sha256": "<64 hexadecimal characters>"
    }
  ]
}
```

The manifest's `createdAt` records when the run started preparing its metadata. Its presence marks completion of all archive uploads; it is
not a database transaction timestamp shared across databases. Archives are individually consistent, not an atomic snapshot across the entire
instance. SHA-256 detects accidental corruption; the manifest is not a cryptographic signature and does not defend against an attacker who
can replace both objects.

After publication, `/backup/.last-success` is atomically updated with a Unix timestamp. Only the exact local archive files belonging to that
successful run are removed. Failed runs remain available for diagnosis. Monitor failed Jobs, age of the last successful backup, and staging
capacity. Review failed-run directories before deleting their specific files; never clear the shared staging root indiscriminately.

The chart does not delete S3 objects or rewrite bucket policies. Apply lifecycle retention to the dedicated prefix, including expiration of
incomplete multipart uploads and, where applicable, noncurrent object versions. Consider Object Lock with a suitable retention policy. A
completed backup should not be your only off-cluster recovery artifact.

## Recovery limits

Full copy-only backups preserve existing differential backup bases. This schedule does not provide point-in-time recovery, manage a
differential/log chain, or truncate the transaction log. For FULL recovery databases, arrange and validate a separate transaction log backup
strategy; otherwise log storage can continue to grow. Do not change recovery models or shrink logs just to conceal this problem.

Database backups do not fully capture server-level logins, login SIDs, jobs, configuration, TLS material, or encryption certificates. Keep
their recovery material separately. Restores cannot be used to downgrade to an older SQL Server engine. Edition feature compatibility and
capacity limits still apply.

## Restore into a fresh instance

1. Create an isolated release with compatible SQL Server version, enough data/log storage, and the intended TLS trust configuration. Keep
   application traffic away until validation finishes.
2. Download a completed run's manifest and archives using a read-scoped recovery identity. Verify every downloaded SHA-256 and byte count
   against the manifest. S3 ETag is not a substitute for SHA-256.
3. Place the verified archive on a volume visible to the target SQL Server at a path under `/backup`. Downloading into the sqlcmd client's
   filesystem alone is insufficient.
4. Use a privileged recovery identity to run `RESTORE FILELISTONLY FROM DISK = N'<server-visible archive>';`. Determine the logical file
   names and map every data/log file to unused destination paths. The backup login intentionally lacks recovery permissions.
5. For a database with one data file and one log file, use the shipped `files/restore.sh` helper from the official SQL Server image. Supply
   SQL_HOST, SQL_PORT, SQLCMDUSER, SQLCMDPASSWORD, SSL_CERT_FILE, RESTORE_DATABASE, RESTORE_FILE, RESTORE_DATA_LOGICAL_NAME, and
   RESTORE_LOG_LOGICAL_NAME. The helper supports the same identifier subset as backup; use a reviewed SQL restore script for other names or
   multiple files.
6. The helper refuses an existing target database and system database names. It performs `RESTORE VERIFYONLY WITH CHECKSUM`, restores using
   explicit MOVE destinations without REPLACE, and runs `DBCC CHECKDB`. It assumes the target data directory is `/var/opt/mssql/data`; adapt
   a reviewed restore script for a different directory.
7. Query known application rows, check users and login mappings, validate application behavior, record actual recovery time, then switch
   traffic through the normal change process.

Never pass passwords on sqlcmd's `-P` argument or enable shell tracing. Use the SQLCMDPASSWORD environment variable sourced from a Secret
and retain TLS verification. `RESTORE VERIFYONLY` checks backup readability but is not a substitute for the real restore and integrity
checks above.

## Sources

- [Microsoft S3 backup support and edition restrictions](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/sql-server-backup-to-url-s3-compatible-object-storage?view=sql-server-ver17)
- [Copy-only backups](https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/copy-only-backups-sql-server?view=sql-server-ver17)
- [RESTORE VERIFYONLY](https://learn.microsoft.com/en-us/sql/t-sql/statements/restore-statements-verifyonly-transact-sql?view=sql-server-ver17)
- [AWS CLI workload identity configuration](https://docs.aws.amazon.com/cli/latest/topic/config-vars.html)
- [S3 incomplete multipart lifecycle rules](https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpu-abort-incomplete-mpu-lifecycle-config.html)
