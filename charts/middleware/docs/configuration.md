<!-- SPDX-License-Identifier: Apache-2.0 -->
# Middleware — Configuration

Middleware is an all-in-one DORA metrics platform. This chart runs the upstream
`middlewareeng/middleware` image (frontend + analytics + sync in one container)
with PostgreSQL and Redis as separate workloads.

## Key values

| Value | Default | Purpose |
|---|---|---|
| `middleware.environment` | `prod` | App environment (`ENVIRONMENT`). |
| `middleware.frontendPort` / `analyticsPort` / `syncPort` | `3333` / `9696` / `9697` | Container ports for the three services. |
| `persistence.enabled` / `persistence.size` | `true` / `1Gi` | PVC for `/app/keys` (encryption keys — keep persisted). |
| `postgresql.enabled` | `true` | Bundle the HelmForge PostgreSQL subchart (DORA data). |
| `redis.enabled` | `true` | Bundle the HelmForge Redis subchart (cache/queues). |
| `externalDatabase.*` / `externalRedis.*` | disabled | Use managed datastores instead of the subcharts. |
| `ingress.*` | disabled | Expose the Web UI via Ingress/TLS. |
| `resources` | `{}` | Set requests/limits (see `examples/production.yaml`). |

## Datastores

By default the chart bundles PostgreSQL (`mhq-oss` database) and Redis. To use
managed datastores, disable the subchart and enable the matching `external*`
block — see [external-datastores.md](external-datastores.md). The app never runs
its embedded Postgres/Redis: `POSTGRES_DB_ENABLED`/`REDIS_ENABLED` are forced off
so data lives on a real, backup-able workload.

## Persistence

The app writes encryption keys to `/app/keys` on first boot and reads them on
every start. Keep `persistence.enabled=true` so the keys survive restarts;
otherwise data encrypted with the old keys becomes unreadable after a restart.
The volume is `ReadWriteOnce`, so the app tier runs a single replica by design
(see [../DESIGN.md](../DESIGN.md)).

## Access

With `ingress.enabled=false` (default), port-forward the Service:

```bash
kubectl port-forward svc/<release>-middleware 3000:80
# open http://localhost:3000/
```

With `ingress.enabled=true`, the Web UI is served at the configured host.
