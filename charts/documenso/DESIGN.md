# Documenso chart design

## Architecture

One Deployment runs the official Documenso image. A ClusterIP Service exposes
port 3000 and optional Ingress or HTTPRoute resources publish it. PostgreSQL is
provided by the maintained HelmForge dependency or by a complete external URL
stored in a Secret. Redis is rendered only for the BullMQ job provider.

## Identity and secret lifecycle

NextAuth and both encryption keys form persistent application identity. The
chart-created Secret uses Helm `lookup` to retain generated values on upgrade.
Production and GitOps installations should supply `documenso.existingSecret`
or materialize it with `externalSecrets.items`. Database, Redis, SMTP, S3,
Gotenberg, and PKCS#12 credentials are referenced from Secrets.

## Migrations and availability

The supported upstream entrypoint runs `prisma migrate deploy` on boot. A
non-root init container waits for PostgreSQL before that entrypoint starts.
Single-replica installs use Recreate. Scale-out requires BullMQ and S3 so jobs
and documents are shared. Operators must size PostgreSQL connection capacity
for every application replica.

Startup and readiness use `/api/health`. TCP liveness avoids restart storms
during a database outage. No ServiceMonitor is rendered because Documenso has
no documented Prometheus endpoint.

## Security boundaries

The container runs as UID/GID 1001 with runtime-default seccomp, no Linux
capabilities, no service-account token, and a read-only root filesystem.
Writable emptyDir mounts are limited to temporary and npm-cache paths. The
optional certificate is mounted read-only from a Secret.

NetworkPolicy permits namespace-local ingress, DNS, selected state services,
and public HTTP/HTTPS while excluding private address ranges. Private external
services and webhook destinations need explicit peers.

## Recovery

PostgreSQL, the S3 bucket when used, the signing certificate, and application
identity Secrets are one recovery set. Redis contains in-flight BullMQ jobs and
should also be protected when job loss is unacceptable. Restore the same
application version in isolation, validate health, login, document access, and
signing, then perform an upgrade.
