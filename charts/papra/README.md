# Papra Helm Chart

Deploy [Papra](https://github.com/papra-hq/papra), a private document archive with extraction, full-text search and
organization-based access control. The chart uses the official `ghcr.io/papra-hq/papra:26.6.2-rootless` image.

## Production defaults

- A single writer with Recreate upgrades, a retained 5 GiB PVC and explicit resource limits.
- Non-root UID/GID 1000, read-only root filesystem, dropped capabilities and no Kubernetes API token.
- Protected first-administrator creation on loopback before the public server starts; existing users are preserved.
- Retained session-signing and initial-password Secrets, with existing Secret and External Secrets Operator support.
- Closed email/password registration, native health probes and default network isolation.
- Local SQLite or authenticated external libSQL; local originals or S3-compatible storage.
- Optional native database encryption and versioned document encryption keys, supplied through Secrets.
- A separate persistent local libSQL task queue, preserving pending extraction work across pod replacement.
- Ingress, Gateway API, dual-stack Services, placement controls and trusted private CA bundles.

Papra does not use PostgreSQL, MySQL or Redis. Its local database and libSQL client share the application's native
migrations. The chart keeps one application replica across all storage combinations.

## Installation and access

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install papra helmforge/papra -f values.yaml
kubectl port-forward svc/papra-papra 1221:1221
```

Set `bootstrap.email` and `bootstrap.name` before installation; the default account is `admin@example.test`. The initial
password is generated once and retained in the Secret reported by Helm NOTES. Prefer `bootstrap.existingSecret` and
`auth.existingSecret` for GitOps. The password is available only to the init container; the public process never
receives the bootstrap password mount.

Bootstrap runs strict native migrations, checks the existing user count and initializes only an empty instance through
Papra's own authentication API. It verifies administrator permissions before stopping its loopback listener. Changing
the bootstrap Secret later does not reset an existing account. Keep the separate `auth` Secret stable to retain
sessions.

For remote access, configure a dedicated HTTPS hostname through `server.publicUrl`, an Ingress or Gateway route, and the
matching `networkPolicy.ingressFrom` peers. Configure edge upload limits and timeouts for your document sizes. See
[production examples](examples/production.yaml).

## Database and document storage

The default PVC contains the local database under `db/` and original documents under `documents/`. The native server
performs extraction and indexing; database records contain metadata and extracted text.

For remote libSQL, set `database.remoteUrl` and `database.authTokenSecret`. Production endpoints should use HTTPS. For a
private CA, mount its bundle with `server.trustedCaSecret`; this extends Node trust without disabling certificate
verification. The chart does not provision a remote database or manage its tokens. Local document storage still requires
the PVC. Remote libSQL cannot use the client's local `database.encryptionSecret` option.

For S3, set `storage.driver: s3`, endpoint, region, bucket and `storage.s3.existingSecret`. The bucket must already
exist. `storage.s3.forcePathStyle` supports compatible endpoints. Allow the destination through NetworkPolicy. The
default SQLite database still needs durable storage when documents are placed in S3. Changing the storage driver does
not automatically migrate existing originals; use the upstream migration procedure with a backup and verified rollback
plan.

See [storage and recovery](docs/recovery.md) and [external storage examples](examples/external-storage.yaml).

## Encryption and key retention

`database.encryptionSecret` enables native encryption of a newly created local database. Preserve its exact value in
every upgrade and restore. Enabling, disabling or rotating this key on an existing database is not an automatic
migration. The chart does not recreate a database when a key is missing or incorrect.

`storage.encryptionSecret` enables native envelope encryption of original documents. Its selected key contains a single
64-hex-character key or a versioned ring such as `001:<64-hex-key>,002:<64-hex-key>`. Each key represents 32 bytes.
Papra orders version labels lexically; use stable, zero-padded labels and keep every version still referenced by
originals. Adding a new version changes encryption of new documents; it does not rewrap all existing documents.

Document encryption protects original files. Extracted text and metadata remain in the database, so protect the database
separately. Database backups, original objects and the complete key ring must be recovered together. For plaintext
documents created before encryption was enabled, use the separate upstream maintenance procedure; startup does not
silently rewrite historical storage.

## Authentication and integrations

The default public process disables first-user privilege grants, email/password signup, unconfigured password reset and
Better Auth telemetry. Existing instances can use their native account-management flows after authentication.

`envFrom` provides an advanced Secret-backed integration path, while chart-managed explicit environment values retain
precedence. Do not put credentials in plain `extraEnv` values. Native custom OAuth providers have a different enrollment
contract from email/password signup: Papra's global registration flag does not restrict custom-provider provisioning.
Restrict access at the identity provider before configuring those providers; do not infer a closed enrollment policy
from `auth.allowRegistration: false`. This chart's validated default authentication is the native password flow.

## Monitoring and operations

Pending extraction tasks live in `db/tasks.sqlite` on the data volume. `tasks.workerEnabled=false` pauses consumption
while leaving the web API available; reenabling it processes retained pending jobs. Include this separate queue and its
WAL files in consistent backups. Its metadata is not encrypted by `database.encryptionSecret`; treat it as private data.

The pinned native queue has no lease/reaper for jobs interrupted in `processing`, extraction retries default to zero,
and completed jobs are retained. Persistent pending work does not guarantee automatic recovery of an interrupted
extraction or a crash between document creation and enqueue. Monitor failed/stuck jobs and queue growth; see
[task lifecycle](docs/tasks.md). The chart does not silently rewrite task state.

Startup/readiness use `/api/health`, including native database health, and liveness uses `/api/ping`. There is no
verified native Prometheus endpoint in this release; the chart does not create a misleading ServiceMonitor. Monitor
workload availability, memory, PVC capacity, application logs and authenticated edge traffic using your existing
platform monitoring.

NetworkPolicy permits same-namespace HTTP ingress and DNS by default. Allow ingress-controller peers and explicit
S3/libSQL/mail/identity-provider destinations. A compatible CNI is required for enforcement. See
[operations](docs/operations.md).

## Upgrade and recovery

Take a consistent database and original-document backup before upgrades. Native migrations run before readiness; Helm
rollback does not reverse data migrations. For local state, stop the writer, archive the database directory including
WAL files and the complete document directory, and retain all Secrets separately. Restore into a fresh PVC with
`persistence.existingClaim`, then authenticate and verify original checksums and search results before reopening access.

PVC retention protects generated claims from ordinary release uninstall. Namespace deletion and external storage
policies can still remove data. Existing claims are managed by their owner. Recreate upgrades deliberately include
downtime.

## Validation

Runtime profiles exercise native bootstrap, administrator permissions, closed registration, organization/document
creation, exact original SHA-256, extraction/search, private-download denial and persistence across pod replacement.
Additional profiles verify encrypted database integrity and wrong-key rejection, encrypted fresh-PVC recovery, signed S3
object reads and unsigned denial, authenticated remote libSQL, and both integrations over trusted HTTPS. The queue
profile pauses the worker, proves the same pending job survives replacement, resumes the native worker and verifies
completion and searchable content without another upload.

Run the repository gate from `helmforge-ops`:

```bash
make validate-chart CHART=papra
```

The complete gate, security scan and release evidence must be green before publication.

## Security Scan: `papra`

| Framework | Score      |
| --------- | ---------- |
| Overall   | **98.48%** |
| MITRE     | **97.06%** |
| NSA       | **97.50%** |
| SOC2      | **90.00%** |

Kubescape 4.0.13, default rendered manifests, 2026-09-10. The sole finding is C-0012 matching the literal boolean
`AUTH_IS_PASSWORD_RESET_ENABLED=false` in the main and bootstrap environments. This is a policy flag, not a password;
actual authentication and encryption credentials use Secrets. The finding remains visible without suppression. This
configuration scan does not replace image vulnerability management or application security review.
