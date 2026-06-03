<!-- SPDX-License-Identifier: Apache-2.0 -->
# Automatisch — Chart Design

Design notes for the HelmForge `automatisch` chart. Automatisch is an
open-source business-automation platform (a self-hosted Zapier alternative:
connect apps, build workflows with triggers and actions).

## Application shape

Automatisch runs two tiers from the same image:

- **web** — the API + UI server, served via the Service on port 80.
- **worker** — background worker that executes workflow jobs from the queue.

Both share configuration/secrets so the datastore and app settings are defined
once.

## Datastores

- **PostgreSQL** (bundled subchart or external) — workflows, connections,
  execution history. The source of truth.
- **Redis** (bundled subchart or external) — the job queue the worker consumes;
  required for workflow execution.

## Persistence

Durable state lives in PostgreSQL; the queue lives in Redis. The app tiers are
otherwise stateless. Scale the worker for throughput and the datastores for
resilience.

## Configuration & secrets

The app encryption/secret keys and the database/Redis passwords come from secrets
(existing-secret first), never templated into a ConfigMap.

## Scaling boundaries

- web: can scale behind the Service.
- worker: scale for job throughput.
- State is external (PostgreSQL/Redis), so there is no app-local RWO bottleneck.

## What this chart deliberately does NOT do

- No embedded datastores (bundled/external PostgreSQL + Redis).

## References

- Project: <https://automatisch.io> · <https://github.com/automatisch/automatisch>
- See [`docs/`](docs/) and [`examples/`](examples/).
