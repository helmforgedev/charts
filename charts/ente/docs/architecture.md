# Ente Architecture

## Runtime components

Museum is Ente's API and control plane. It owns database migrations, account
flows, metadata, presigned S3 URLs, Prometheus metrics, and background jobs.

The web image contains static builds for multiple Ente applications. This chart
runs one web Deployment and exposes a Service for every enabled application.

PostgreSQL stores durable metadata and encryption material. S3 stores encrypted
objects. Neither is independently sufficient for recovery.

## Request flow

1. A client connects to Photos, Accounts, or Albums over HTTPS.
2. Static JavaScript calls the public Museum API origin.
3. Museum reads and writes metadata in PostgreSQL.
4. Museum creates a presigned S3 request.
5. The client transfers encrypted data directly to S3.

This direct path is why an internal-only object endpoint is not sufficient.

## Configuration flow

The chart mounts an explicit `/museum.yaml` instead of setting upstream's
`ENVIRONMENT=production`. The upstream production file enables internal TLS and
file logging, which are inappropriate defaults for Kubernetes. The chart uses
HTTP inside the cluster, TLS at Ingress or Gateway, and stdout logging.

Secrets override the non-sensitive ConfigMap through `ENTE_*` environment
variables. Dots and hyphens in Museum keys become underscores.

## Health model

Startup and readiness call `/ping`, which runs `SELECT 1` against PostgreSQL.
Liveness uses TCP port 8080 so a database outage does not trigger restart loops.
S3 needs a separate functional check because `/ping` does not contact it.

## Durable state

Museum and web pods have no persistent volumes. Museum's temporary replication
directory and nginx writable paths use emptyDir volumes. Durable state belongs
to PostgreSQL, S3, and Kubernetes Secrets.

## Related guides

- [Object storage](object-storage.md)
- [High availability](high-availability.md)
- [Backup and restore](backup-restore.md)
- [Security](security.md)
