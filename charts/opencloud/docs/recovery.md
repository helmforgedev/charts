# OpenCloud recovery

## Recovery unit

Preserve the whole PVC: config/opencloud.yaml and all data, including IDM, IDP keys, file storage, metadata and extended
attributes. Copying only visible file content loses native identity or PosixFS metadata. Keep bootstrap and TLS Secrets
separately. Encrypt backups and restrict access: the native configuration and identity files contain secrets.

## Consistent archive

Schedule maintenance, stop writes, scale the monolithic Deployment to zero and wait for its Pod to terminate. Mount
the source volume read-only in an authorized helper. Use a volume snapshot or GNU tar with --xattrs --acls; verify your
backup product preserves all filesystem attributes required by your storage backend. Keep UID/GID 1000 and private
file modes. The validation archive uses the official PostgreSQL image only as a pinned GNU tar helper; OpenCloud does
not depend on a PostgreSQL server.

Restore into a fresh, isolated xattr-capable PVC. Extract with --xattrs --acls --no-same-owner --no-overwrite-dir as the
application UID when using an fsGroup-prepared destination. Restore both config and data; configure
persistence.existingClaim with that new volume and retain the canonical origin and certificate trust.

## Acceptance

Verify exact checksums of native configuration, IDP encryption.key and private-key.pem. Check xattrs on restored
metadata, perform a new native browser login and compare private WebDAV file bytes. Also confirm anonymous and
incorrect-token requests are denied. Only then switch production traffic; retain the previous recovery source until
your rollback window closes. Do not run two instances concurrently against one identity/data directory.

The local recovery scenario passed fresh-PVC restoration with an xattr sentinel, identical identity keys, fresh
OIDC login and exact private file bytes. This is a tested maintenance procedure, not an automated backup scheduler,
remote S3 backup integration, or a measured recovery-time objective.
