# Papra storage and recovery

## Recovery set

Keep a consistent recovery set containing the database, original document objects, session-signing Secret, database
encryption key if enabled, and every document-encryption key version still in use. Include operator-managed
configuration and integration Secrets. A database backup alone does not contain filesystem/S3 originals, and document
objects alone cannot reconstruct organization metadata, permissions or wrapped file keys.

For local state, scale the application Deployment to zero and wait for its pod to terminate. Archive `db/`, `documents/`
and any additional configuration stored on the PVC. Preserve SQLite WAL files rather than copying only a live database.
Use storage snapshots only with a consistency guarantee appropriate to the whole recovery set.

For remote libSQL or S3, use the provider's backup/versioning procedures and coordinate the application's writes so the
database and originals represent a compatible recovery point. The chart does not automatically migrate historical
objects when `storage.driver` changes.

## Restore procedure

1. Provision a fresh PVC with the required size and ownership; keep the original volume intact.
2. Restore the complete local recovery set while the application remains stopped.
3. Restore remote database/object state if used, and materialize the original Secrets.
4. Set `persistence.existingClaim` to the recovered PVC and preserve native database/storage configuration.
5. Start one writer; confirm strict migrations and native readiness succeed.
6. Authenticate, verify organization access, download original documents and compare SHA-256, and verify search results.
7. Reopen traffic only after the checks pass.

The chart runtime gate follows this procedure for encrypted local database and documents, verifies account/session
retention and exact original bytes on the fresh volume, and confirms the database rejects missing or wrong encryption
keys. The restore helper archives explicit state directories, avoiding ownership changes to the storage-provider-managed
PVC root.

## Key changes

Choose a local database encryption key before first database creation. Changing or removing that key is not an online
migration; retain the exact original key for recovery. Remote libSQL encryption belongs to its server/provider and
cannot use the local client's `DATABASE_ENCRYPTION_KEY` option.

Document key-ring labels are compared lexically. Use zero-padded versions and retain old keys until no original refers
to them. Adding a new key version only affects new encryption. The native plaintext-encryption maintenance command does
not rewrap documents that are already encrypted. Never delete an older key merely because a newer version is configured.

Document envelope encryption protects originals. Extracted text and metadata reside in the database and require their
own encryption and access policy.
