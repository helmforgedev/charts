<!-- SPDX-License-Identifier: Apache-2.0 -->
# Appwrite — Chart Design

Design notes for the HelmForge `appwrite` chart. Appwrite is a self-hosted
backend-as-a-service (auth, databases, storage, functions, realtime, messaging).

## Application shape

Appwrite is a multi-service application. The chart renders the main API plus the
companion deployments the platform needs:

- **api** — the HTTP API (port 80) and the entrypoint clients talk to.
- **realtime** — websocket pub/sub for live updates.
- **console** — the admin web UI.
- **workers** — a set of background workers (audits, builds, certificates,
  databases, deletes, functions, mails, messaging, migrations, webhooks, ...).
- **scheduler / maintenance** — periodic and housekeeping tasks.

All share a common environment (`appwrite.commonEnv`) so the datastore and
feature configuration is defined once.

## Datastores

- **MariaDB** (bundled subchart or external) — the primary database. Appwrite 1.9
  defaults `_APP_DB_ADAPTER` to `mongodb`; this chart provisions MariaDB and
  therefore sets `_APP_DB_ADAPTER=mariadb` explicitly (`database.adapter`) so the
  workers speak the MySQL protocol, not the Mongo wire protocol.
- **Redis** (bundled subchart or external) — cache, queues and pub/sub backbone
  shared by the API, realtime and workers.

## Persistence

Appwrite keeps uploads, function code/builds and certificate cache on persistent
volumes (`persistence.*`). These are `ReadWriteOnce`, so the stateful tiers are
single-replica by design; scale the datastores (managed MariaDB/Redis) for
resilience rather than the app pods.

## Configuration & secrets

The database password is sourced from the bundled MariaDB secret or an external
existing secret; it is never templated into a ConfigMap. Feature toggles (usage
stats, GraphQL limits, SMTP, logging provider) are passed via `commonEnv` and
`appwrite.*`.

## Scaling boundaries

This chart targets a single-node-capable footprint with many small deployments.
On a constrained node the workers may queue (FailedScheduling/backoff) during
startup until resources free up; give the platform adequate CPU/memory.

## What this chart deliberately does NOT do

- No MongoDB adapter (MariaDB only — `_APP_DB_ADAPTER=mariadb`).
- No embedded datastores inside app pods (always bundled/external workloads).
- No HA for the stateful tiers (RWO volumes — single replica by design).

## References

- Project: <https://appwrite.io> · <https://github.com/appwrite/appwrite>
- See [`docs/`](docs/) and [`examples/`](examples/).
