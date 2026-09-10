# Identity backup and recovery

An identity provider backup must preserve the database, native uploads, exact encryption key and relying-party origin.
Changing any one independently can invalidate credentials, signing material or sessions. Store backups and Secrets under
access controls appropriate for the identities they contain.

## SQLite

1. Schedule downtime and stop the application Deployment. Wait for its pod to terminate so native SQLite connections and
   actor processing are closed.
2. Snapshot the complete persistent volume or archive every entry in `/app/data`, including hidden files and any SQLite
   sidecars. Preserve file modes and ownership. Archive directory contents rather than overwriting the root metadata of
   a provisioned destination PVC.
3. Back up the encryption Secret through your secret-management system. An externally managed key must be restored from
   the same source; generating another random key does not recover the old encrypted fields.
4. Restore the archive into a fresh PVC that UID/GID1000 can access. Keep the same public HTTPS origin and original
   encryption Secret, then set `persistence.existingClaim` to the restored claim.
5. Start one replica. Confirm the initializer preserves the existing account and the public setup endpoint remains
   closed. Verify a previously enrolled passkey, existing OIDC client, signed token and private account state before
   routing production traffic to the restored instance.

Keep the source backup and original volume until recovery has been accepted. Recovery testing should use an isolated
environment and controlled DNS routing so two independent instances do not serve the same production identity.

## PostgreSQL

Quiesce Pocket ID before taking a consistent PostgreSQL backup and matching uploads snapshot. Include application and
Francis actor schemas and preserve the same encryption Secret. Use a database backup procedure appropriate to the actual
PostgreSQL major, extension versions, ownership and recovery objective. Prepare `citext` and `pgcrypto` on the
destination before native startup.

The chart does not automatically convert SQLite into PostgreSQL, coordinate database PITR with upload snapshots or
reverse database migrations during Helm rollback. A successful PostgreSQL startup/restart check is not a PostgreSQL
disaster-recovery drill; validate that procedure separately against your managed database or subchart deployment.

## Operator access

If no enrolled device remains usable, an authorized operator can invoke the native `one-time-access-token` CLI as
described in [onboarding](onboarding.md). This produces a short-lived access credential; it does not replace a lost
database or encryption key. Treat the command output as a Secret and enroll a new device promptly.
