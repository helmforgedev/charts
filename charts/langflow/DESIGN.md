# Langflow Chart Design

This chart packages Langflow as a web/API Deployment backed by a persistent config directory.
Langflow is not a stateless frontend: flows, local configuration, generated SQLite data, provider settings, and encrypted secrets all depend
on persistent state or an external database.

## Runtime Model

- Workload: Deployment.
- HTTP UI/API: port `7860`.
- Local state: `/app/langflow`.
- Default database: SQLite in the persistent config directory.
- Production database: external SQLAlchemy-compatible URL through `LANGFLOW_DATABASE_URL`.
- Secret encryption/JWT signing: `LANGFLOW_SECRET_KEY`.

## Scaling Model

The default single-replica mode is safe with SQLite and a PVC.
Horizontal scaling is only allowed when a shared external database is configured.
The chart enforces this because multiple replicas with independent SQLite files would diverge flows and user state.

## Secrets Model

The chart supports:

- auth Secret for `LANGFLOW_SECRET_KEY`, `LANGFLOW_SUPERUSER`, and `LANGFLOW_SUPERUSER_PASSWORD`
- database Secret for `LANGFLOW_DATABASE_URL`
- `app.env` and `app.envFrom` for provider credentials and flow global variables

Inline secret values are intended for tests and labs. Production examples use existing Secrets.

## Non-Goals

- Bundling PostgreSQL as a subchart.
- Managing exported flows as Kubernetes resources.
- Running separate frontend/backend/celery topologies. This chart deploys the official all-in-one Langflow image.
