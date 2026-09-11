# Twenty design

One Recreate Pod contains native server, worker and public proxy. A private initializer runs strict migrations and
native administrator/workspace enrollment. PostgreSQL and authenticated persistent Redis use HelmForge dependencies. The
admission helper verifies each Pod address family under an enforcing CNI before the native wildcard listener starts.
This is bounded network evidence with trusted namespace policy ownership, not universal isolation.

## Identity and migrations

Native configuration is environment-owned with `IS_CONFIG_VARIABLES_IN_DB_ENABLED=false`. The initializer checks
ownership before migrations and serializes native database initialization, upgrades and cache refreshes. Command success
requires both exit status and native completion evidence because upstream commands can swallow errors. Enrollment uses
native authentication and workspace mutations without SQL password or privilege writes. Public workspace invites are
disabled explicitly.

Retain `SERVER_ID`, `ENCRYPTION_KEY` and the ownership marker with the database. Completed ownership follows native user
and workspace IDs across password changes. An existing database without the matching marker is refused before migration.
Private initialization diagnostics use a mode-0600 file removed on success.

## Dependency and file contracts

PostgreSQL and Redis can each use a HelmForge subchart or an external endpoint. External connections support
authenticated TLS with certificate and hostname verification. Redis is durable queue state and uses append-only
persistence and noeviction. Arbitrary restrictive Redis ACLs require separate compatibility tests.

Local files share one PVC between native server and worker. S3 changes file placement, while the PVC still retains
installation ownership. Native file upload and completion APIs enforce application authorization; signed download URLs
are temporary bearer capabilities. Browser-to-bucket presigned transfer is disabled. Additional CAs are combined before
starting native Node processes.

## Mail, metrics and recovery

SMTP uses authenticated implicit TLS on port 465, matching the native transport. Disabled SMTP uses a refused loopback
transport to avoid upstream LOGGER output containing recovery links. Operators must enable delivery before relying on
mail.

The server alone exports native Prometheus metrics on private port 9464. Its ServiceMonitor and availability rule
require explicit network ingress. The worker does not bind a competing exporter. Worker readiness proves registration,
while behavioral acceptance requires a completed native job and its stored SDK archive.

Recreate deployment keeps migration and local storage ownership serial. No HA or horizontal scaling is claimed. Recovery
needs a coordinated database, files, identity and Redis snapshot. Acceptance restores to fresh database and PVCs and
checks retained application identity, records, files and delayed native work. Anonymous product telemetry is disabled.
SSO licensing, hosted functions, AI providers and third-party account synchronization are outside this contract.
