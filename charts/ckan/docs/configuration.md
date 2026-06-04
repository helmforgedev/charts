<!-- SPDX-License-Identifier: Apache-2.0 -->
# CKAN — Configuration

CKAN is an open-data portal. This chart runs CKAN plus the components it depends
on: **PostgreSQL** (catalog + DataStore), **Redis** (cache/queue), **Solr**
(search index) and **DataPusher** (tabular ingestion).

## Key values

| Value | Default | Purpose |
|---|---|---|
| `postgresql.enabled` | `true` | Bundle the HelmForge PostgreSQL subchart. |
| `externalDatabase.*` | — | Managed PostgreSQL (when `postgresql.enabled=false`). |
| `redis.enabled` | `true` | Bundle Redis (cache + background tasks). |
| `solr.*` | enabled | Search index (own PVC); CKAN search depends on it. |
| `datapusher.*` (port 8800) | enabled | Pushes tabular resources into the DataStore. |
| `persistence.*` | `true` | PVC for uploaded resource files. |
| `ingress.*` | disabled | Expose the portal. |

## Components and ports

- **ckan** — web app/API (Service on 80, app on 5000).
- **Solr** (8983) — must be available for dataset search to work.
- **DataPusher** (8800) — imports CSV/Excel resources into the DataStore DB.

## Datastores

CKAN uses PostgreSQL for the main catalog and (typically) the DataStore database,
Redis for caching/background tasks, and Solr for search. Use bundled subcharts
for small installs or point CKAN at managed PostgreSQL via `externalDatabase.*`.
Passwords come from secrets, never templated into ConfigMaps.

## First boot

On first start CKAN initializes its schema; the bootstrap logs include benign
`relation "..." does not exist` messages from PostgreSQL before the tables are
created — these are expected and clear once initialization completes.

## Persistence and scaling

Uploaded resource files (PVC) and the Solr index (separate PVC) are `ReadWriteOnce`
stateful volumes, so the app/Solr tiers run a single replica. Scale the datastores
for resilience; back up PostgreSQL (catalog + DataStore) and the resource PVC.
