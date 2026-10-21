# Operations and recovery

## Before an upgrade

1. Back up PostgreSQL and verify the backup.
2. Snapshot the attachment PVC or versioned S3 bucket.
3. Export the application identity and integration Secrets securely.
4. Record the deployed image digest and chart version.
5. Test restoration in an isolated namespace.

## Upgrade

Review upstream migrations, then use `helm upgrade --install --wait`. Confirm
the migration init container completed, the Deployment is ready,
`/up` returns success, logs contain no fatal errors, and document upload and
signing work.

## Recovery

Restore the database, attachments, and original application identity Secret as
one consistent set. Deploy the recorded image version first. Validate login,
document access, signing, email, and background jobs before changing versions.

## Scale-out

Move PostgreSQL, Redis, and attachments to shared production services before
raising `replicaCount`. The chart rejects mixed local/shared configurations to
avoid divergent state.
