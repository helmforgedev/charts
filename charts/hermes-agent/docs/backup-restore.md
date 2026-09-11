# Backup and restore

## Scheduled backups

Enable `backup.enabled`, select the schedule/time zone and configure `backup.s3`. Use a dedicated bucket/prefix and an existing Secret with `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY` and optionally `AWS_SESSION_TOKEN`. AWS S3 uses the default endpoint; compatible storage accepts an HTTPS endpoint and optional
`caSecret` containing `ca.crt`. TLS verification is never disabled. The HTTP opt-in exists for explicitly trusted test networks.

The CronJob uses `concurrencyPolicy: Forbid`, no retry of a partially completed run and a bounded active deadline. A required same-node affinity permits a
second Pod to mount a ReadWriteOnce volume. ReadWriteOncePod is rejected. The producer holds the native backup lock, creates SQLite online snapshots, checks
full database integrity and builds an inventoried ZIP. The uploader cannot mount the agent PVC.

Upload permissions need PutObject and GetObject for the dedicated prefix. The chart neither lists nor deletes backups. For SSE-KMS, grant the necessary KMS
encryption/decryption permissions and configure the key ID. Bucket lifecycle controls retention and abandoned partial prefixes. The completed remote layout is:

```text
<prefix>/hermes-<UTC timestamp>-<random suffix>/backup.zip
<prefix>/hermes-<UTC timestamp>-<random suffix>/manifest.json
```

The uploader streams the uploaded ZIP back through SHA-256 verification before writing `manifest.json`. An archive without its completion manifest is not a
successful backup. Checksums detect corruption; they are not signatures against an authorized malicious bucket writer. Protect access and consider bucket
versioning/immutability according to your retention requirements.

## Consistency and scope

SQLite snapshots use the native online backup API and include committed WAL state. Full integrity checks run without the native size-based shortcut. Files are
captured as observed, with exact member hashes. Separate databases, config, cron definitions and workspace files are not captured in a single transaction.
Quiesce agent work when your recovery point requires a stable cross-file application state.

The backup follows the pinned native exclusion policy for regenerable caches, downloaded runtimes/models, dependencies, SQLite sidecars, nested backup artifacts
and symlinks. The chart additionally excludes runtime PID/lock/status/process files, gateway control sockets and its own recovery markers. Unexpected special
files, disappearing included files, unreadable files or failed SQLite snapshots fail the Job. Active file-set changes can require retrying during a quieter
period.

Included persistent data can contain config, `.env`, upstream authentication files, local vault encryption keys, profiles, memory, learned skills, sessions,
cron and workspace contents. Treat the archive as sensitive as the live agent. Environment-only Kubernetes Secrets, mounted external credentials and remote
memory/provider services need independent backup. The chart does not traverse arbitrary external paths or restore the native `_external/` namespace.

## Recovery into a new volume

Create a separate release/PVC and restore from the exact completed manifest key. Keep provider and other external Secrets available in the target namespace.
Reuse the S3 connection settings even when scheduled backup is disabled:

```yaml
fullnameOverride: hermes-recovered
credentials:
  existingSecret: hermes-provider
backup:
  enabled: false
  s3:
    bucket: organization-agent-backups
    existingSecret: hermes-recovery-s3
restore:
  enabled: true
  manifestKey: hermes-agent/hermes-20260911T120000Z-0123456789abcdef/manifest.json
```

The prepare init container rejects nonempty state before downloading. Recovery checks the manifest/ZIP hashes, member inventory, paths, permissions, sizes and
SQLite integrity in staging. Only a fully validated archive is copied to the empty target. The incomplete marker stays present until published files are
reverified; a failed copy cannot start the agent.

After success, the exact manifest key is recorded on the volume. Subsequent restarts skip downloading and preserve current state. Disable `restore.enabled`
after recovery and verification. Changing the manifest key on an already populated volume is rejected; there is no force/overwrite mode. `config.policy=managed`
then reconciles the new release's declared config, so explicitly choose the provider/model configuration you intend to run.

Staging must hold the archive plus extracted files for restore, and the archive plus an individual database snapshot for backup. Size `backup.stagingSize`,
`restore.maxArchiveBytes` and `restore.maxExpandedBytes` together. Staging is disk-backed emptyDir and consumes node ephemeral storage; monitor both the PVC and
node disk.

Verify an authenticated agent turn, old session history and memory in a fresh session before directing production traffic to the recovered release. The local
acceptance suite performs this recovery against HTTPS S3-compatible storage and checks that a second Pod startup does not replay the restore.

The snapshot walker opens every path component relative to a pinned directory descriptor with symlink following disabled. SQLite snapshots use a pinned file
descriptor as their source while preserving native online backup and WAL semantics. Directory replacement is covered by a failure-injection test, and descriptor
cleanup is checked on rejection.
