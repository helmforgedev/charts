# Middleware Helm Chart

Deploy [Middleware](https://www.middlewarehq.com) on Kubernetes using the official [middlewareeng/middleware](https://hub.docker.com/r/middlewareeng/middleware) container image. Open-source DORA metrics platform that measures Deployment Frequency, Lead Time, MTTR, and Change Failure Rate for engineering teams.

## Features

- **DORA metrics** — measures all four DORA metrics from CI/CD integrations
- **PostgreSQL + Redis** — uses HelmForge subcharts or external services
- **All-in-one container** — frontend, analytics, and sync server in one image
- **Internal services disabled** — uses Kubernetes-native PostgreSQL and Redis instead of bundled services
- **Persistent storage** — API keys and config on PVC
- **Ingress support** — TLS with cert-manager

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install middleware helmforge/middleware -f values.yaml
```

**OCI registry:**

```bash
helm install middleware oci://ghcr.io/helmforgedev/helm/middleware -f values.yaml
```

## Basic Example

```yaml
# values.yaml — default values are sufficient
# Uses bundled PostgreSQL and Redis subcharts
```

After deploying:

```bash
kubectl port-forward svc/<release>-middleware 3333:80
# Open http://localhost:3333
```

## External Database and Redis

```yaml
postgresql:
  enabled: false

redis:
  enabled: false

externalDatabase:
  enabled: true
  host: your-postgres-host
  name: mhq-oss
  user: middleware
  password: "your-password"

externalRedis:
  enabled: true
  host: your-redis-host
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `middleware.frontendPort` | `3333` | Frontend port |
| `middleware.analyticsPort` | `9696` | Analytics API port |
| `middleware.syncPort` | `9697` | Sync server port |
| `middleware.environment` | `prod` | Environment |
| `postgresql.enabled` | `true` | Enable bundled PostgreSQL |
| `redis.enabled` | `true` | Enable bundled Redis |
| `externalDatabase.enabled` | `false` | Use external database |
| `externalRedis.enabled` | `false` | Use external Redis |
| `persistence.enabled` | `true` | Enable persistence for /app/keys |
| `persistence.size` | `1Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `service.port` | `80` | Service port |

## Limitations

- **Single instance** — the all-in-one container does not support horizontal scaling
- **Resource-heavy** — recommended 16GB RAM for production workloads
- **Internal services disabled** — the container's bundled PostgreSQL and Redis are disabled in favor of Kubernetes-native subcharts

## More Information

- [Middleware documentation](https://docs.middlewarehq.com)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/middleware)

<!-- @AI-METADATA
type: chart-readme
title: Middleware Helm Chart
description: README for the Middleware DORA metrics platform Helm chart

keywords: middleware, dora, metrics, devops, engineering, performance

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/middleware/values.yaml
path: charts/middleware/README.md
version: 1.0
date: 2026-04-01
-->
