<!-- SPDX-License-Identifier: Apache-2.0 -->
# Apache Superset — Chart Design

Design notes for the HelmForge `superset` chart. Superset is a business
intelligence / data-exploration platform (SQL Lab, dashboards, charts).

## Application shape

Three long-running tiers plus a one-shot initializer:

- **web** — the Superset (Gunicorn) web server, served via the Service on port 80.
- **worker** — Celery workers for async queries and thumbnails.
- **beat** — the Celery beat scheduler for periodic jobs.
- **init Job** — runs `superset db upgrade` (Alembic migrations) + `superset init`
  (Flask-AppBuilder roles/permissions) + admin creation.

## Init ordering (important)

The init Job is a **managed Job** (not a post-install hook) so it runs
concurrently with the web/worker/beat pods, and those pods carry a
`wait-for-init` initContainer that blocks until the Job completes. This is
deliberate: if web/worker/beat start before the schema exists they each race to
run Flask-AppBuilder's `create_db`, which **deadlocks in PostgreSQL**. Waiting for
the single init Job removes the race. (See `templates/init-job.yaml`,
`_helpers.tpl: superset.waitForInit`, and the wait RBAC.)

## Datastores

- **PostgreSQL** (bundled or external) — the metadata database (dashboards,
  charts, users). The source of truth.
- **Redis** (bundled or external) — Celery broker/result backend and cache.

## Persistence

Superset's durable state lives in PostgreSQL; the app tiers are stateless and can
scale horizontally (web/worker), with beat kept at a single replica (one
scheduler). Scale PostgreSQL/Redis for resilience.

## Configuration & secrets

`SUPERSET_SECRET_KEY`, DB and Redis passwords come from secrets; the SQLAlchemy
URI and Redis URL are assembled at runtime via `$(DB_PASSWORD)`/`$(REDIS_PASSWORD)`
interpolation, never written to a ConfigMap.

## What this chart deliberately does NOT do

- It does not let web/worker/beat self-initialize the schema (single init Job).
- No embedded datastores (bundled/external PostgreSQL + Redis).

## References

- Project: https://superset.apache.org · https://github.com/apache/superset
- See [`docs/`](docs/) and [`examples/`](examples/).
