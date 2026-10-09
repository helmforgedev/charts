# Ghostfolio chart design

## Goals

The chart turns the upstream Docker contract into a repeatable Kubernetes
deployment without replacing Ghostfolio behavior. It keeps the official
entrypoint, migrations, database seed, health endpoints, runtime user, and
configuration names intact.

## Architecture

One `Deployment` owns the Ghostfolio process. A `Service` exposes port 3333;
optional Ingress or HTTPRoute resources provide public access. PostgreSQL and
Redis are either HelmForge subcharts or external services with explicit Secret
contracts. The application has no persistent volume because portfolio state is
stored in PostgreSQL.

Two non-root BusyBox init containers wait for state-service TCP listeners. This
prevents an avoidable entrypoint failure but is not treated as application
readiness. Prisma performs authenticated migrations and `/api/v1/health` proves
database and Redis functionality.

## Singleton invariant

The upstream entrypoint applies migrations and seeds before every server start.
The application also enables scheduled work by default. No distributed lock or
leader election is documented for either responsibility. `replicaCount` is
therefore schema- and template-constrained to one and the Deployment uses
`Recreate`, preventing overlapping old and new processes during upgrades.

## Identity and credential lifecycle

Access-token and JWT salts form persistent application identity. The generated
Secret uses cluster lookup to survive Helm upgrades. An existing Secret is the
production and GitOps contract because offline rendering cannot retrieve live
values. OIDC, external database, Redis, and provider secrets are referenced,
never copied into chart-owned ConfigMaps or Deployment literals.

External database mode consumes a complete URL so reserved password characters
remain URL-encoded by the Secret producer. `DIRECT_URL` can bypass a pooler for
Prisma migrations. Bundled PostgreSQL uses an alphanumeric dependency-generated
password and constructs both URLs in environment expansion.

## Security boundaries

The official image runs as UID/GID 1000. The chart drops all capabilities,
disables privilege escalation, uses runtime-default seccomp, mounts no API
token, and makes the root filesystem read-only. EmptyDir mounts provide only the
temporary and npm-cache paths needed by the migration entrypoint.

NetworkPolicy permits the dependencies and public market-data HTTP/HTTPS while
excluding private destinations from broad egress. Operators must enumerate
private external peers. This makes the trust expansion visible in values.

## Availability and recovery

Availability comes from Kubernetes process recovery and durable state services,
not multiple Ghostfolio replicas. The startup probe allows five minutes for
migrations. Liveness excludes dependency checks to avoid restart storms, while
readiness removes traffic when PostgreSQL or Redis is unavailable.

PostgreSQL backup and restore remain infrastructure responsibilities. Redis is
rebuildable operational state. Recovery must include application salts because
changing them affects authentication independently of database restoration.

## Deliberate omissions

There is no HPA or PodDisruptionBudget because replicas are fixed at one. There
is no application PVC because upstream does not document durable local files.
There is no ServiceMonitor because upstream exposes no documented Prometheus
endpoint. These omissions prevent false production guarantees.
