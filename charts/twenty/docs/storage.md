# Native file storage

Local storage lives at `/app/data/storage` on the retained application PVC. Server and worker share one Pod so they can
safely share an ordinary RWO claim. Temporary SDK generation uses a bounded writable `/tmp`; the image remains
read-only. The generated frontend configuration has a separate writable file.

`storage.driver=s3` configures the native S3 driver on both server and worker. Use an existing private bucket, signing
region and credential Secret. The default keys are `access-key-id` and `secret-access-key`. An optional compatible
endpoint must use HTTPS. Native upstream addressing is path-style.

An additional CA bundle applies before native Node startup. Certificate and hostname verification remain enabled. The
integration acceptance compares bytes from a native attachment against the actual stored object, requires unsigned
access to fail and checks incorrect CA/hostname rejection. It also requires the native worker's SDK ZIP in the same
bucket, with its database checksum recorded. This acceptance passed, including
the original session, company and exact attachment bytes after Pod replacement.

Browser transfers use native signed application endpoints, not a private cluster bucket hostname. The chart disables
native presigned direct-to-bucket transfers. A signed application download URL is intentionally a time-limited
capability; possession can permit download without a separate login until it expires.

The PVC still stores `.helmforge-identity.json` with S3 enabled. Preserve it and the native key Secret with database and
bucket recovery points. S3 storage is not an S3 backup schedule; configure independent bucket protection and retention.
The fresh-PVC restore profile proves local storage recovery, not S3 disaster recovery.
