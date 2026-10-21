# DocuSeal chart design

## Goals

The chart provides a conservative production deployment of DocuSeal 3.3.3 with
immutable image provenance, durable state, explicit secrets, least-privilege
runtime settings, and reproducible validation.

## Workloads

One Deployment runs the web application and embedded background processing. An
init container executes `rails db:prepare` before every application Pod starts,
making schema readiness part of Pod readiness. Rails migration locking protects
concurrent HA rollouts. The default `Recreate` strategy prevents two single-node
instances from competing for local ReadWriteOnce storage. Validated HA
configuration switches to rolling updates.

## Dependencies

HelmForge PostgreSQL and Redis are enabled by default. External endpoints are
exclusive alternatives and require Secret references plus explicit
NetworkPolicy peers. This keeps credentials out of rendered manifests and
prevents an apparently valid but unreachable production configuration.

## Storage

Local attachments use a retained PVC. S3-compatible storage is required for
multiple replicas. `/tmp` is a bounded `emptyDir`, allowing a read-only image
root while preserving temporary runtime writes.

## Security

The pod runs as the official image UID/GID 2000 with RuntimeDefault seccomp,
all Linux capabilities dropped, no privilege escalation, no service-account
token, and a read-only root filesystem. Default NetworkPolicy denies unrelated
traffic while permitting the application dependencies.

## Upgrade and rollback

Database migrations are forward-moving. Back up PostgreSQL, attachments, and
identity secrets before upgrading. Application rollback is safe only when the
corresponding database schema remains backward compatible; otherwise restore
the matched backup set.
