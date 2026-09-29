# Attic storage and backup

Attic metadata and stored NAR/chunk objects form one consistency domain. A
usable backup must cover both.

## Standalone mode

SQLite and local objects share `/data` on one PVC. Before a snapshot:

1. stop or drain builders that can upload;
2. scale the API Deployment to zero so SQLite WAL state is quiescent;
3. take a storage-native VolumeSnapshot or consistent volume backup;
4. restore the snapshot into a test namespace;
5. start Attic and pull a known store path.

Copying only `server.db` is insufficient. The database references objects in
`/data/storage`, and SQLite may have active WAL files.

The generated PVC has `helm.sh/resource-policy: keep` by default. Uninstalling
the release therefore does not delete cache data. Removing a retained PVC is a
separate, deliberate operation.

## Distributed mode

PostgreSQL holds metadata while S3 holds objects. Recommended controls:

- PostgreSQL continuous archiving or managed PITR;
- S3 bucket versioning;
- encryption at rest and in transit;
- lifecycle retention longer than the database recovery window;
- periodic restore exercises.

For a coordinated recovery point, pause uploads and garbage collection, record
the PostgreSQL backup position and preserve corresponding S3 object versions.
Garbage collection can otherwise delete objects referenced by an older
database restore.

## Garbage collection

Attic collection proceeds through cache mappings, global NARs and global
chunks. Set retention per cache with the Attic client. The chart's default
global retention is zero, so time-based deletion is not enabled accidentally.

Only one garbage collector may run in distributed mode. The chart enforces one
replica and Recreate strategy for that component.

## S3-compatible services

Set `storage.s3.endpoint` for MinIO, Garage, Ceph RGW or another compatible
service. Ensure the endpoint is reachable by external consumers when Attic
returns presigned URLs. Prefer workload identity when the platform supports it;
otherwise place access keys in the existing Secret.

## Capacity planning

Chunked NARs can consume large amounts of object storage even with global
deduplication. Monitor:

- PVC usage in standalone mode;
- S3 bytes, object count and request errors;
- PostgreSQL size and connection saturation;
- cache retention settings and GC logs;
- upload latency and proxy 5xx responses.

Changing chunk sizes changes deduplication behavior for future uploads. Keep
the defaults stable unless measurements justify a migration.
