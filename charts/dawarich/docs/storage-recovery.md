# Storage and coordinated recovery

The application PVC retains local ActiveStorage objects, public assets, watched
imports and the identity fingerprint. Rails and Sidekiq share those paths in one
Recreate Pod. A writable private TMPDIR is created with mode 0700 for Ruby multipart
uploads; making the container image writable is unnecessary.

## Native S3

Set `storage.driver: s3` with `storage.s3.bucket`, `region` and `existingSecret`.
The Secret supplies access and secret keys. `endpoint` is optional for AWS S3 and
must use HTTPS when configured. A private CA can be supplied with `caSecret`/`caKey`;
the native AWS SDK receives it through AWS_CA_BUNDLE without disabling verification.

The pinned upstream storage configuration explicitly accepts credentials; ambient
IAM identity and arbitrary SDK options are not chart promises. In particular,
upstream does not expose a force-path-style setting. For compatible endpoints, the
SDK chooses addressing from endpoint and bucket rules; the acceptance fixture uses
a dotted bucket name over HTTPS and confirms native path addressing. Verify your
backend's naming and addressing requirements before migrating existing objects.

S3 changes where ActiveStorage stores objects. It does not remove the application
PVC, create a backup policy or make the co-located workload horizontally scalable.
Native signed object URLs are bearer links; protect them as access credentials.
Apply bucket access, encryption, versioning and retention controls separately.

## Recovery sequence

1. Stop public writes and quiesce both Rails and Sidekiq. Allow in-flight jobs to
   finish within the maintenance window; inspect queued/retrying work.
2. Take a checked PostgreSQL dump and a matching full filesystem archive/snapshot.
   For S3, preserve the corresponding object versions as well.
3. Retain all four identity keys, connection Secrets and the application origin.
   Keep backups encrypted and access-controlled outside the cluster.
4. Restore into a compatible PostGIS database and a fresh application PVC. Install
   extensions as DBA, restore application objects under the application role, and
   preserve custom spatial reference rows with the required DBA privileges.
5. Point the release at the restored database and PVC. Let the serialized native
   migration/admission sequence finish before restoring traffic.
6. Verify the actual database name, native login including 2FA, imported coordinates,
   completed import state and the original attachment bytes. Review queues and
   external integrations before resuming writers.

The dedicated `ci/restore-values.yaml` fixture uses pg_dump/pg_restore, a new database
and a new PVC. It retains the source until disposable namespace cleanup. PostGIS
extension creation entries are handled by the DBA; custom `spatial_ref_sys` rows are
restored separately with checked errors rather than discarded. Native ActiveStorage
downloads verify the original GPX bytes after recovery.

This is a coordinated offline recovery strategy. PVC retention is not an off-cluster
backup, and the chart does not claim an application-consistent live filesystem copy,
automatic downgrade or transparent recovery of every interrupted Sidekiq job.
