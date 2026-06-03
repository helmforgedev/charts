<!-- SPDX-License-Identifier: Apache-2.0 -->
# Flowise — Chart Design

Design notes for the HelmForge `flowise` chart. Flowise is a visual builder for
LLM/AI orchestration flows (drag-and-drop chains, agents, RAG).

## Two deployment modes

The chart supports the two upstream operating modes:

1. **Standalone (default)** — a single Flowise pod using an embedded **SQLite**
   database on a persistent volume. Simplest; good for small/single-user installs.
2. **Queue mode** — for scale: Flowise main + workers coordinate via **Redis**
   (queue) and persist to **PostgreSQL** instead of SQLite. Enable the
   `postgresql`/`redis` subcharts (or point at managed ones) to use it.

The chart keeps standalone as the default so the chart works out-of-the-box with
no external datastores, and lets operators opt into queue mode for production.

## Datastores

- `postgresql.enabled` — bundled PostgreSQL for queue mode (or `externalDatabase`).
- `redis.enabled` — bundled Redis queue for queue mode (or external).
- SQLite (standalone) lives on the app PVC.

## Persistence

`persistence.enabled` backs `/root/.flowise` (flows, credentials, and the SQLite
DB in standalone mode) with a `ReadWriteOnce` volume → single app replica in
standalone mode. In queue mode the durable state is in PostgreSQL/Redis and
workers scale horizontally.

## Configuration & secrets

App credentials and database/redis passwords come from secrets (existing-secret
first), never templated into ConfigMaps. The app serves on port 3000.

## Scaling boundaries

- Standalone: single replica (SQLite on RWO volume).
- Queue mode: scale workers; PostgreSQL/Redis hold shared state.

## References

- Project: <https://flowiseai.com> · <https://github.com/FlowiseAI/Flowise>
- See [`docs/`](docs/) and [`examples/`](examples/).
