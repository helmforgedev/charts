# Docmost Chart Design

This chart packages Docmost as a single application Deployment backed by
PostgreSQL, Redis, and either local persistent storage or S3-compatible object
storage.

## Architecture

```text
User
  |
  +-- Ingress or Gateway API HTTPRoute
        |
        +-- Service
              |
              +-- Deployment
                    |-- Docmost application
                    |-- local uploads PVC or S3
                    |-- PostgreSQL subchart or external PostgreSQL
                    +-- Redis subchart or external Redis
```

## Design Choices

- Default installs use HelmForge PostgreSQL `2.0.2` and Redis `1.6.16`
  subcharts so database/cache lifecycle stays inside the HelmForge ecosystem.
- `replicaCount` defaults to one because local uploaded-file storage is
  single-writer. Operators that need horizontal scaling should first move
  uploads to shared object storage and validate upstream runtime behavior.
- The chart uses only the standard `gateway` block for Gateway API routing.
- External services are first-class for managed PostgreSQL and Redis setups.
- External Secrets Operator support is limited to credential materialization and
  requires existing Secret wiring to avoid drift.
- The backup CronJob is optional and targets PostgreSQL dumps uploaded to
  S3-compatible storage.

## Security And Operations

The chart exposes pod/container security contexts, scheduling controls,
resource configuration, Secret indirection, Gateway API, Ingress, dual-stack
Service options, and backup settings. Defaults are intentionally conservative
for a practical single-instance install.

## Non-Goals

- The chart does not claim multi-replica safety with local storage.
- The chart does not provision object storage or external databases.
- The chart does not keep `Chart.lock`; dependencies are resolved by the
  repository release workflow.

## Validation Focus

- Default deployment with bundled PostgreSQL and Redis
- External PostgreSQL/Redis rendering
- Ingress and Gateway API rendering
- External Secrets rendering
- Backup CronJob rendering
- Dual-stack Service rendering

## Related Files

- `charts/docmost/README.md`
- `charts/docmost/docs/architecture.md`
- `charts/docmost/examples/simple.yaml`
- `charts/docmost/examples/external-services.yaml`

---

keywords: docmost, design, postgresql, redis, gateway-api, external-secrets
path: charts/docmost/DESIGN.md
