<!-- SPDX-License-Identifier: Apache-2.0 -->
# Middleware — Chart Design

Design notes and rationale for the HelmForge `middleware` chart. Middleware is an
open-source **DORA metrics** platform (deployment frequency, lead time for
changes, change failure rate, time to restore) for engineering teams.

## Application shape

The upstream image `middlewareeng/middleware` is an **all-in-one** container: a
single process tree runs three logical services on three ports:

| Service       | Port  | Role                                            |
|---------------|-------|-------------------------------------------------|
| frontend      | 3333  | Next.js web UI                                  |
| analytics API | 9696  | metrics computation / REST API                  |
| sync server   | 9697  | ingestion from Git providers (GitHub/GitLab)    |

The chart therefore models **one Deployment, one container** with three named
container ports, fronted by a single Service that targets the frontend port.

Persistent state lives in two places:

- **PostgreSQL** (`mhq-oss` database) — all DORA data, settings, and provider
  integrations. The source of truth.
- **Redis** — cache and background-job queues used by the sync/analytics paths.
- **`/app/keys`** — the app generates encryption keys on first boot and reads
  them on every start; they MUST survive restarts (see Persistence below).

## Datastores: bundled vs external

The chart can either bundle the datastores (HelmForge `postgresql`/`redis`
subcharts, default) or point at managed ones:

- `postgresql.enabled` (default `true`) provisions the bundled PostgreSQL and the
  app's `DB_*` env is wired to it. Set `externalDatabase.enabled=true` (and
  `postgresql.enabled=false`) to use a managed PostgreSQL instead.
- `redis.enabled` (default `true`) provisions the bundled Redis. Set
  `externalRedis.enabled=true` (and `redis.enabled=false`) for a managed Redis.

The app's own `POSTGRES_DB_ENABLED`/`REDIS_ENABLED` flags are forced to `false`
(`middleware.internalDbEnabled`/`internalRedisEnabled`) so the image never starts
its *embedded* Postgres/Redis — the chart always supplies them as first-class
Kubernetes workloads (bundled or external). This keeps data on a real,
backup-able StatefulSet/managed service rather than inside the app pod.

## Startup ordering

An init container (`wait-for-postgresql`) blocks until the database TCP port is
reachable before the app starts, so the first boot doesn't crash-loop while the
bundled PostgreSQL is still initializing. Redis is optional at boot and is
retried by the app.

## Persistence and the single-replica boundary

`/app/keys` is backed by a `ReadWriteOnce` PVC (`persistence.enabled=true`,
default `1Gi`). Because the encryption keys are stateful and the volume is RWO,
the Deployment is intended to run **a single replica** — there is no HA/multi-replica
mode for the app tier in this chart. Scale the *datastores* (managed PG/Redis) for
resilience, not the app pod. Disabling persistence (`persistence.enabled=false`)
makes the keys ephemeral and is only acceptable for throwaway/dev installs, where
re-encryption on restart is tolerable.

## Configuration & secrets

- The database password is taken from the bundled subchart secret, an
  `externalDatabase.existingSecret`, or an inline value, in that order of
  preference (`existingSecret` wins). No password is ever templated into a
  ConfigMap.
- `middleware.environment` (default `prod`) and `middleware.timezone` are passed
  through as env; arbitrary extra env goes via `middleware.extraEnv`.

## Probes

Startup/liveness/readiness probes target the frontend port. The startup probe is
generous (`failureThreshold * periodSeconds`) because first boot runs migrations
and key generation; liveness/readiness are tight once the app is up.

## What this chart deliberately does NOT do

- No app-tier HA (RWO keys volume — single replica by design).
- No embedded datastores inside the app pod (always external/bundled workloads).
- No ingress/TLS by default (opt-in via `ingress.*`).

## References

- Project: <https://github.com/middlewarehq/middleware>
- Chart docs: see [`docs/`](docs/) and [`examples/`](examples/).
