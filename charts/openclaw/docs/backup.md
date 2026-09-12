# Native backup and S3 recovery

Enable `backup.enabled` with a persistent claim, an S3 bucket and an existing credential Secret. The CronJob uses
`concurrencyPolicy: Forbid`, a deadline and no automatic Job retries. It schedules on the gateway's node so RWO storage
can be mounted concurrently; ReadWriteOncePod is incompatible with this online backup workflow.

The snapshot init container runs OpenClaw's native `backup create --verify --json`. The archive includes discovered
state, configured agent roots, config dependencies, credentials and workspaces. Canonical SQLite databases use online
snapshots, including committed WAL data, and native integrity/ownership verification. This is per-database consistency,
not one transaction spanning every database and workspace file. Third-party SQLite files outside owned agent roots
may be ordinary file copies. Quiesce the application if cross-file atomicity is required.

Native backups deliberately remove transient leases and delivery queue records. Recovery is not an exactly-once
continuation of external actions. Some logs, volatile files and plugin dependency trees are excluded. Protect exports
or custom external data separately. Kubernetes Secrets, model-provider accounts, external browser state and object
storage are not restored by an application archive.

The AWS CLI container receives only the completed archive volume and S3 credentials. It uploads to a unique run prefix,
reads the remote archive back to verify SHA-256, then uploads the completion manifest last. Only a successful Job and
completed manifest establish offsite success; OpenClaw's local backup status alone does not. Interrupted runs can leave
objects without a manifest. Configure bucket lifecycle for retention and incomplete multipart uploads.

Use HTTPS; a private endpoint can use a CA Secret with `ca.crt`. HTTP requires an explicit insecure-endpoint opt-in for
trusted environments. SSE-S3 and SSE-KMS are supported; configure KMS permissions separately. Backups contain credentials
and conversation state: scope the storage identity to the required prefix and protect object access. Checksums detect
corruption but are not signatures against an attacker who can rewrite both archive and manifest.

## Recovery procedure

1. Select a completed manifest and preserve the old deployment/state for investigation.
2. Use a new empty claim and the matching upstream image version. Stop any writers that might use that destination.
3. Configure `restore.enabled`, `restore.manifestKey`, S3 credentials and size limits. Keep messaging disconnected while
   validating the recovered installation.
4. Init containers download bounded data, validate checksum and native archive integrity, extract to staging, and activate
   assets into empty persisted home. External asset paths are rejected for automatic activation and need manual recovery.
5. Confirm gateway health, known sessions, workspaces and credentials before reconnecting external channels. Review pending
   actions; ratchet-based credentials can require relinking after rollback.
6. A completion marker makes restarting the same restored release idempotent. Changing the manifest on existing state is
   rejected. Interrupted activation leaves a marker and requires inspection and a fresh claim; it never overwrites state.

Staging needs room for the archive and snapshot scratch space. Restore additionally needs extracted data plus the final
state copy. `backup.stagingSize` is an emptyDir ceiling, not reserved disk; provision node ephemeral capacity and scheduling
resources accordingly. The native archive has no universal data-size limit; chart restore limits bound downloads and
expanded entries. Test recovery with representative data and storage throughput before setting deadlines.
