# Atuin chart design

## Topologies

The default is a single Atuin Deployment using SQLite on a ReadWriteOnce PVC. The chart fixes the rollout strategy to
`Recreate` and rejects replicas or autoscaling in this mode because SQLite is not a shared multi-writer database.

PostgreSQL mode uses either the maintained HelmForge PostgreSQL dependency or an existing Secret containing a complete
database URI. The application is otherwise stateless, so replicas, rolling updates, topology spreading, a disruption
budget and HPA become available. Upstream does not promise mixed-version zero-downtime upgrades; operators should back
up before upgrades and assess release notes before scaling rollouts.

## Database URI handling

Atuin only accepts a complete URI. External database mode therefore consumes `ATUIN_DB_URI` directly from a Secret. For
bundled PostgreSQL, a short-lived Node init container URL-encodes the generated password and writes the URI to an
in-memory volume. The main container reads it immediately before `exec` and the URI never enters a ConfigMap or pod
command rendered with credentials.

Embedded migrations run in every server startup. The chart does not invent a migration Job or migration command that
upstream does not provide. Each PostgreSQL replica can use up to 100 connections; database capacity and HPA limits must
reflect that.

## Persistence and security

The official image runs as UID/GID 1000. Kubernetes enforces non-root execution, RuntimeDefault seccomp, dropped
capabilities and a read-only root filesystem. `/config` is a PVC for SQLite and an `emptyDir` for PostgreSQL because
Atuin creates `server.toml` there. `/tmp` is also an `emptyDir`. Service account token mounting is disabled.

## Health and metrics

All probes call the upstream `/healthz` endpoint and follow `atuin.path`. This proves HTTP process availability but not
continuing database health. Behavioral validation additionally verifies startup created the SQLite database. Prometheus
metrics are opt-in on a separate port and Service so they are never exposed by public HTTP routes.

## Exposure and secrets

Ingress and Gateway API are first-class. TLS is strongly required because upstream warns that login credentials travel
in clear text over plain HTTP. External Secrets uses a native `items[]` spec passthrough rather than inventing
provider-specific fields.

## Unsupported claims

Atuin Server 18.23.0 has no native S3 backend. The chart intentionally has no `s3` application values. Object storage
can be used by an operator's PostgreSQL backup system, but that is independent of Atuin.
