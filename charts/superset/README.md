# Apache Superset

Apache Superset is a modern, enterprise-ready business intelligence web application
for data exploration and visualization. It supports 60+ database connectors,
interactive dashboards, SQL Lab, and a rich set of visualizations.

## Features

- **Three-component architecture** — web server (Gunicorn), Celery worker, and Celery beat scheduler as separate Deployments for independent scaling
- **Init Job** — automatic database migration, Superset initialization, and admin user creation via Helm hook
- **PostgreSQL subchart** — bundled metadata store with option for external database
- **Redis subchart** — bundled Celery broker and result backend with option for external Redis
- **superset_config.py via ConfigMap** — extend Superset configuration through `superset.extraConfig`
- **Auto-generated secrets** — admin password, Flask SECRET_KEY, database and Redis passwords
- **Health probes** — startup, liveness, and readiness probes on `/health`
- **Ingress support** — configurable with `ingressClassName` (traefik, nginx, etc.)

## Install

### Helm repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install superset helmforge/superset -f values.yaml
```

### OCI registry

```bash
helm install superset oci://ghcr.io/helmforgedev/helm/superset --version <version> -f values.yaml
```

## Architecture

```text
Deployment: superset-web (Gunicorn, port 8088)
Deployment: superset-worker (Celery workers)
Deployment: superset-beat (Celery beat scheduler)
Job: superset-init (DB migrate + admin creation)
  ├─ PostgreSQL (subchart)
  └─ Redis (subchart)
```

## Default Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `apache/superset` | Container image |
| `image.tag` | `""` (appVersion) | Image tag |
| `superset.adminUsername` | `admin` | Admin username |
| `superset.adminPassword` | `""` (auto) | Admin password |
| `superset.secretKey` | `""` (auto) | Flask SECRET_KEY |
| `superset.loadExamples` | `false` | Load example dashboards |
| `web.replicaCount` | `1` | Web server replicas |
| `web.workers` | `2` | Gunicorn workers |
| `web.timeout` | `120` | Gunicorn timeout |
| `worker.enabled` | `true` | Enable Celery workers |
| `worker.replicaCount` | `1` | Worker replicas |
| `worker.concurrency` | `2` | Celery concurrency |
| `beat.enabled` | `true` | Enable Celery beat |
| `init.enabled` | `true` | Enable init job |
| `database.mode` | `subchart` | Database mode: subchart or external |
| `redisConfig.mode` | `subchart` | Redis mode: subchart or external |
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `80` | Service port |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `traefik` | Ingress class |
| `postgresql.enabled` | `true` | Enable PostgreSQL subchart |
| `redis.enabled` | `true` | Enable Redis subchart |

## External Database

```yaml
postgresql:
  enabled: false

database:
  mode: external
  external:
    host: postgres.example.com
    port: 5432
    name: superset
    username: superset
    password: my-password
```

## External Redis

```yaml
redis:
  enabled: false

redisConfig:
  mode: external
  external:
    host: redis.example.com
    port: 6379
    password: redis-password
    db: 0
```

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: traefik  # or nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: superset.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: superset-tls
      hosts:
        - superset.example.com
```

## Custom Configuration

Extend `superset_config.py` via `superset.extraConfig`:

```yaml
superset:
  extraConfig: |
    FEATURE_FLAGS = {
        "DASHBOARD_NATIVE_FILTERS": True,
        "DASHBOARD_CROSS_FILTERS": True,
    }
    ROW_LIMIT = 50000
```

<!-- @AI-METADATA
type: chart-readme
title: Apache Superset Helm Chart
description: Apache Superset BI platform with web, worker, and beat deployments backed by PostgreSQL and Redis

keywords: superset, bi, analytics, visualization, dashboard, celery

purpose: Installation, configuration, and operational guide for the Superset Helm chart
scope: charts/superset

relations:
  - charts/superset/values.yaml
  - charts/superset/Chart.yaml
path: charts/superset/README.md
version: 1.0
date: 2026-04-01
-->
