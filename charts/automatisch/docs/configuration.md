<!-- SPDX-License-Identifier: Apache-2.0 -->
# Automatisch — Configuration

Automatisch is an open-source business-automation platform (a self-hosted Zapier
alternative). This chart runs two tiers from the same image — a **web** server
(API + UI, Service on port 80) and a **worker** that executes workflow jobs —
backed by PostgreSQL and Redis.

## Key values

| Value | Default | Purpose |
|---|---|---|
| `postgresql.enabled` | `true` | Bundle the HelmForge PostgreSQL subchart. |
| `externalDatabase.*` | — | Managed PostgreSQL (when `postgresql.enabled=false`). |
| `redis.enabled` | `true` | Bundle Redis — the job queue the worker consumes. |
| `externalRedis.*` | — | Managed Redis (when `redis.enabled=false`). |
| `worker.*` | enabled | Worker tier replicas/resources. |
| `ingress.*` | disabled | Expose the UI. |

## Datastores

- **PostgreSQL** — workflows, connections and execution history (source of truth).
- **Redis** — the job queue; required for the worker to execute flows.

Use the bundled subcharts for small installs, or point at managed datastores via
`externalDatabase.*` / `externalRedis.*`. The encryption/app keys and datastore
passwords come from secrets (existing-secret first), never templated into a
ConfigMap.

## Access

With ingress disabled, port-forward the Service:

```bash
kubectl port-forward svc/<release>-automatisch 3000:80
# open http://localhost:3000/  and create the first admin account
```

## Scaling

The web tier scales behind the Service; the worker scales for job throughput.
State is external (PostgreSQL/Redis), so there is no app-local volume bottleneck —
scale the datastores for resilience and back up PostgreSQL.
