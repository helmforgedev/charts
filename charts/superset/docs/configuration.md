<!-- SPDX-License-Identifier: Apache-2.0 -->
# Apache Superset — Configuration

Superset is a BI / data-exploration platform (SQL Lab, dashboards, charts). This
chart runs three tiers — **web** (Service on port 80), **worker** (Celery) and
**beat** (Celery scheduler) — plus a one-shot **init Job**, backed by PostgreSQL
and Redis.

## Key values

| Value | Default | Purpose |
|---|---|---|
| `postgresql.enabled` | `true` | Bundle the HelmForge PostgreSQL subchart (metadata DB). |
| `database.external.*` | — | Managed PostgreSQL (`database.mode: external`). |
| `redisConfig.*` / `redis.enabled` | `true` | Celery broker/result backend + cache. |
| `worker.*` / `beat.*` | enabled | Celery worker/scheduler tiers. |
| `init.enabled` / `init.waitImage` | `true` | Init Job (db upgrade + FAB init + admin) and the kubectl image its waiter uses. |
| `superset.adminUsername` / `adminPassword` | `admin` / generated | First admin user. |
| `superset.installPythonPackages` | `true` | Install Python dependencies when each Superset process starts. |
| `superset.extraPythonPackages` | `[]` | Optional Python packages installed in every Superset process. |
| `ingress.*` | disabled | Expose the web UI. |

## Init ordering (why there is a wait-for-init)

The init Job runs `superset db upgrade` (Alembic) + `superset init` (Flask-AppBuilder
roles/permissions) + admin creation. It is a **managed Job** (not a post-install
hook), and the web/worker/beat pods carry a `wait-for-init` initContainer that
blocks until it completes. This prevents the three tiers from racing each other on
Flask-AppBuilder schema creation, which otherwise **deadlocks in PostgreSQL**.
When `init.enabled=false`, the wait initContainer is omitted too. See
[../DESIGN.md](../DESIGN.md).

## Datastores

- **PostgreSQL** — Superset metadata (dashboards, charts, users). Source of truth.
- **Redis** — Celery broker/result backend and cache.

Use bundled subcharts or managed datastores (`database.mode: external`,
`redisConfig.mode: external`). The SQLAlchemy URI and Redis URL are assembled at
runtime with `$(DB_PASSWORD)`/`$(REDIS_PASSWORD)` from secrets, never templated
into a ConfigMap.

## Optional Python dependencies

`superset.extraPythonPackages` adds database drivers and extensions to the
existing runtime dependency installation for web, worker, beat, and init. Each
entry must be a package name with an optional version constraint; direct URLs
and environment markers are not accepted. Pin tested versions:

```yaml
superset:
  extraPythonPackages:
    - clickhouse-connect==0.13.0
```

Runtime installation is convenient but makes pod startup depend on the package
index. Production deployments should derive an immutable image from the pinned
Superset image, preinstall `psycopg2-binary`, `redis`, and all additional
packages, select it with `image.repository` and `image.tag`, and set
`superset.installPythonPackages: false`.

## Access

```bash
kubectl port-forward svc/<release>-superset 8088:80
# open http://localhost:8088/  (login with the admin user above)
```

## Scaling

web/worker scale horizontally; keep beat at a single replica (one scheduler).
State is in PostgreSQL/Redis — scale those for resilience.
