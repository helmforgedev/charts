# Upload storage

Local uploads use the retained application PVC by default. Set `storage.driver: s3`
for an existing private bucket and provide its credentials through `storage.s3.existingSecret`.
The native application explicitly supplies access and secret keys; this contract does not
claim workload identity, temporary session credentials or automatic bucket provisioning.

Custom endpoints must use HTTPS. `forcePathStyle` supports compatible services without
bucket wildcard DNS. An optional PEM CA Secret augments the native Node trust store;
certificate chain and hostname verification stay enabled. When SMTP and S3 supply different
private CAs, the launcher combines them before starting the native process. These additional
CAs apply to all TLS clients in that process, rather than only one integration.

The bucket must permit scoped list, read, write and delete operations. Native readiness writes
and deletes its `healthcheck` object. Uploads use authenticated requests without public object
ACLs; the application serves picture URLs through its own public upload proxy. A private
bucket therefore does not make a resume picture confidential to authenticated application users.
Native private AI attachments have separate access rules and are outside this chart's current
validated feature set.

The PVC remains required in S3 mode for the retained user and key fingerprint marker. Back up
PostgreSQL, the retained signing/encryption Secrets, that marker and the bucket together.
Switching storage drivers does not migrate existing files. S3 runtime acceptance compared
native upload bytes with the stored object, rejected unsigned reads, verified certificate
and hostname failures, and retained public picture delivery after Pod replacement.
