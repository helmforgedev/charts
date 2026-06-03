<!-- SPDX-License-Identifier: Apache-2.0 -->
# Wallabag — Chart Design

Design notes for the HelmForge `wallabag` chart. Wallabag is a self-hosted
**read-it-later** application (save web pages, read them later via web UI, REST
API and browser extensions).

## Application shape

The upstream `wallabag/wallabag` image is a Symfony (PHP-FPM + nginx) app served
on port 80. The chart runs it as a single Deployment + Service, with PostgreSQL
as the database. Wallabag also supports MySQL/SQLite upstream, but this chart
standardizes on **PostgreSQL** (bundled subchart or external) for a real,
backup-able datastore.

## Datastore

- `postgresql.enabled=true` (default) provisions the HelmForge PostgreSQL
  subchart (database `wallabag`). The app's `SYMFONY__ENV__DATABASE_*` env is
  wired to it.
- Set `postgresql.enabled=false` and fill `database.external.*` to use a managed
  PostgreSQL. The password comes from `database.external.existingSecret` (or an
  inline value).

## Redis (optional, async)

`redis.enabled` (default `false`) is opt-in. With Redis, wallabag offloads
article imports and annotation processing to async queues; without it those run
synchronously in the request. Enable Redis for heavier import workloads.

## Persistence

`persistence.enabled=true` (default) backs wallabag's data directory (downloaded
article images/assets) with a `ReadWriteOnce` PVC. Because the volume is RWO and
the data is local, the app tier runs a **single replica** — there is no
multi-replica/HA mode in this chart. Disabling persistence makes saved images
ephemeral.

## Backup

The chart ships an optional backup CronJob (`backup.enabled`, default `false`,
schedule `0 3 * * *`): it runs `pg_dump` of the wallabag database to
S3-compatible storage. This is the supported disaster-recovery path — the PVC
holds only re-downloadable assets, while the database is the real state. See
[`docs/backup-restore.md`](docs/backup-restore.md).

## Credentials

An admin user is created from a generated (or supplied) secret. Retrieve it from
the release secret key `wallabag-password` (shown in NOTES.txt). Database and
backup credentials follow the same existing-secret-first pattern.

## Probes

HTTP probes on port 80 against the app root. The startup probe is generous to
cover first-boot schema setup; liveness/readiness are tight once up.

## What this chart deliberately does NOT do

- No app-tier HA (RWO data volume — single replica by design).
- No MySQL/SQLite path (PostgreSQL only, for backup/operability).
- Redis and backup are opt-in, off by default.

## References

- Project: https://github.com/wallabag/wallabag · https://wallabag.org
- See [`docs/`](docs/) and [`examples/`](examples/).
