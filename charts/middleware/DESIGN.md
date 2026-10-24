<!-- SPDX-License-Identifier: Apache-2.0 -->
# Middleware chart design

## Scope

The chart deploys Middleware 0.3.1 as a single Kubernetes application pod and
connects it to either the HelmForge PostgreSQL subchart or an external
PostgreSQL service. It owns application startup ordering, schema migration,
encryption-key persistence, frontend exposure, probes, and baseline workload
security.

The chart uses the official `middlewareeng/middleware` image without rebuilding
or patching it. Design constraints therefore follow the actual behavior of that
tag, not assumptions from generic web applications.

## Architecture

The upstream image contains a supervisor process that starts a Next.js
frontend, a Python analytics API, a sync server, cron, and optionally embedded
PostgreSQL and Redis processes. This chart disables embedded PostgreSQL and
enables embedded Redis. PostgreSQL is a separate Kubernetes workload; Redis is
bound to loopback inside the application container.

One Deployment runs one application container. One Service exposes only the
frontend named port. The analytics, sync, and embedded Redis listeners remain
pod-internal but are checked by startup and readiness probes. A PVC is mounted at
`/app/backend/analytics_server/mhq/config`, where upstream 0.3.1 creates
`config.ini` with the RSA key pair used for integration credentials.

An init container uses the same official image and its packaged `dbmate` binary
to wait for PostgreSQL and apply the shipped migrations. It writes
`/tmp/pubsub/db_init` to a shared `emptyDir`. The upstream analytics process
waits for this file when embedded PostgreSQL is disabled, so the signal is part
of the application startup contract rather than an optional optimization.

## Design decisions

### Separate PostgreSQL, embedded Redis

PostgreSQL contains durable DORA records and benefits from a StatefulSet or a
managed service. The chart therefore keeps it outside the application pod.

Middleware 0.3.1 does not expose a remote Redis password setting. Its Redis
client hard-codes an empty password and enables TLS whenever `REDIS_HOST` is not
`localhost`. A normal authenticated Redis subchart is therefore incompatible.
The chart uses the upstream embedded Redis process and rejects legacy
`redis.enabled` and `externalRedis.enabled` values instead of presenting a
configuration that silently fails during real workloads.

### Explicit migration ownership

The image's original database initializer is coupled to embedded PostgreSQL and
cannot initialize a remote database. The chart-owned init container runs only
the application migrations and uses a Secret-backed password. `dbmate --wait`
handles database startup races deterministically.

### Single application replica

The upstream image combines several stateful processes, stores encryption keys
on a `ReadWriteOnce` volume, and provides no supported leader-election or
multi-replica model. The chart fixes the replica count at one and uses
`Recreate` to avoid concurrent access during upgrades.

### Real port configuration

The three `middleware.*Port` values are passed as `PORT`,
`ANALYTICS_SERVER_PORT`, and `SYNC_SERVER_PORT`, plus matching internal URLs.
They therefore alter the real listeners. `service.port` remains a separate
client-facing value and targets the named frontend port.

## Production boundary

Production operators must provide resilient PostgreSQL, regular PostgreSQL
backups, and a recoverable key PVC. The database and key material form one
logical recovery set. Managed PostgreSQL is recommended when its availability,
backup, and TLS features exceed the bundled subchart requirements.

The chart does not claim application-tier high availability. Pod recreation
causes a service interruption, and the embedded Redis cache and locks are lost
with the pod. This is consistent with the supported upstream runtime. Resource
requests and limits remain operator-defined because repository size, provider
count, and historical ingestion volume vary substantially.

## Security boundary

The chart owns Kubernetes-side controls: a dedicated ServiceAccount without an
API token by default, RuntimeDefault seccomp, no privilege escalation, dropped
capabilities, Secret-backed database passwords, and restricted ingress. Egress
is open because integrations contact user-selected external providers.

The official image starts as root, expands runtime archives into `/opt` and
`/app`, runs supervisor, and starts cron. Consequently, `runAsNonRoot` and a
read-only root filesystem are not safe chart defaults. Removing that boundary
requires an upstream image redesigned for an immutable non-root runtime.

An inline external database password is accepted for compatibility but is
rendered only into a Secret. Production GitOps should use
`externalDatabase.existingSecret` or an external secret controller.

## Observability boundary

Kubernetes observes the three process listeners through probes and captures the
supervisor logs from stdout. The init container has separate migration logs.
The chart does not create a ServiceMonitor or application dashboards because
Middleware 0.3.1 does not expose a stable chart-owned Prometheus contract.

Operators should alert on pod readiness, restarts, migration failures,
PostgreSQL health, PVC capacity, and backup age. Provider-specific ingestion
health remains visible in the Middleware application.

## Known gaps

- Remote Redis is unavailable until upstream supports explicit TLS and
  authentication configuration.
- The application tier is single-replica and has an upgrade interruption.
- The upstream image must run as root with a writable filesystem.
- The chart cannot verify consistency between PostgreSQL and key-PVC backup
  recovery points.
- Network egress cannot be restricted generically because provider endpoints
  are selected by each operator.

## Non-goals

- Rebuilding or patching the upstream container image.
- Running embedded PostgreSQL inside the application pod.
- Claiming multi-replica or zero-downtime application upgrades.
- Provisioning provider credentials or GitHub/Jira/PagerDuty integrations.
- Managing PostgreSQL backups beyond documenting the recovery contract.
- Exposing analytics or sync listeners outside the pod.

## References

- [Upstream source](https://github.com/middlewarehq/middleware)
- [Configuration reference](docs/configuration.md)
- [Operations and recovery](docs/operations.md)
- [Security model](docs/security.md)
