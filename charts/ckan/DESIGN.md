<!-- SPDX-License-Identifier: Apache-2.0 -->
# CKAN — Chart Design

Design notes for the HelmForge `ckan` chart. CKAN is an open-source **open-data
portal** (dataset catalog, search, data API).

## Application shape

CKAN is a multi-component platform; the chart wires the pieces it needs:

- **ckan** — the web application (port 80 via the service; app on 5000) serving
  the portal UI and API.
- **DataPusher** (port 8800) — imports tabular data into CKAN's DataStore.
- **Solr** (port 8983) — the search index CKAN depends on for dataset search.
- **PostgreSQL** — the main database (catalog) and, typically, the DataStore DB.
- **Redis** — cache and background-task broker.

## Datastores and search

- `postgresql.enabled` provisions the bundled PostgreSQL (or `externalDatabase`).
- `redis.enabled` provisions the bundled Redis (or external).
- Solr runs with its own persistent volume (`persistence`) for the index; it MUST
  be available for CKAN to serve search.

## Persistence

CKAN stores uploaded resources/files on a `ReadWriteOnce` PVC, and Solr keeps its
index on a separate volume. Both are stateful → single replica per tier. Scale
the datastores, not the app pod.

## Startup ordering

CKAN depends on PostgreSQL, Solr and Redis being reachable; init/readiness gating
keeps it from serving before its dependencies are up. The first boot runs DB
initialization (the bootstrap logs include benign "relation does not exist"
messages before tables are created).

## Configuration & secrets

DB/Redis/Solr connection settings and the admin/secret keys come from secrets and
values; passwords are never templated into ConfigMaps.

## What this chart deliberately does NOT do

- No app-tier HA (RWO storage + Solr index — single replica by design).
- No external Solr wiring by default (bundled Solr).

## References

- Project: https://ckan.org · https://github.com/ckan/ckan
- See [`docs/`](docs/) and [`examples/`](examples/).
