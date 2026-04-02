# CKAN

CKAN is the world's leading open-source data management system for powering data hubs and data portals. It is used by national and local governments, research institutions, and other organizations to manage and publish collections of data.

## Features

- **CKAN application** — uWSGI-based Python application serving the data portal on port 5000
- **DataPusher** — optional companion service for automatic resource loading (CSV, Excel to DataStore)
- **Solr StatefulSet** — built-in search engine with CKAN-specific schema configuration
- **PostgreSQL subchart** — bundled metadata store with option for external database
- **Redis subchart** — bundled task queue and caching layer with option for external Redis
- **Auto-generated secrets** — sysadmin password, session secret, JWT secret
- **Persistent storage** — PVC for uploaded datasets at `/var/lib/ckan`
- **Health probes** — startup, liveness, and readiness probes on `/api/action/status_show`
- **Ingress support** — configurable with `ingressClassName` (traefik, nginx, etc.)
- **Plugin system** — configure CKAN plugins via `ckan.plugins`

## Install

### Helm repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install ckan helmforge/ckan -f values.yaml
```

### OCI registry

```bash
helm install ckan oci://ghcr.io/helmforgedev/helm/ckan --version <version> -f values.yaml
```

## Architecture

```
Deployment: ckan (uWSGI, port 5000)
Deployment: datapusher (port 8800)
StatefulSet: solr (port 8983)
  ├─ PostgreSQL (subchart)
  └─ Redis (subchart)
```

## Default Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `ckan/ckan-base` | CKAN container image |
| `image.tag` | `""` (appVersion) | Image tag |
| `ckan.siteUrl` | `http://localhost:5000` | Public site URL |
| `ckan.sysadminName` | `admin` | Sysadmin username |
| `ckan.sysadminPassword` | `""` (auto) | Sysadmin password |
| `ckan.plugins` | `envvars image_view text_view datatables_view` | Active plugins |
| `ckan.replicaCount` | `1` | CKAN replicas |
| `datapusher.enabled` | `true` | Enable DataPusher |
| `solr.enabled` | `true` | Enable built-in Solr |
| `solr.persistence.size` | `5Gi` | Solr data volume size |
| `database.mode` | `subchart` | Database mode: subchart or external |
| `redisConfig.mode` | `subchart` | Redis mode: subchart or external |
| `persistence.enabled` | `true` | Enable CKAN storage persistence |
| `persistence.size` | `10Gi` | CKAN storage volume size |
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
    ckanDatabase: ckan
    datastoreDatabase: datastore
    username: ckan
    password: my-password
```

## External Redis

```yaml
redis:
  enabled: false

redisConfig:
  mode: external
  external:
    url: "redis://:password@redis.example.com:6379/0"
```

## Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: traefik  # or nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: ckan.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: ckan-tls
      hosts:
        - ckan.example.com
```

## Plugins

Configure CKAN plugins via `ckan.plugins`:

```yaml
ckan:
  plugins: "envvars image_view text_view recline_view datastore datapusher spatial_metadata spatial_query"
```

<!-- @AI-METADATA
type: chart-readme
title: CKAN Helm Chart
description: CKAN open data portal with DataPusher, Solr, PostgreSQL, and Redis

keywords: ckan, data, portal, open-data, catalog, api, solr

purpose: Installation, configuration, and operational guide for the CKAN Helm chart
scope: charts/ckan

relations:
  - charts/ckan/values.yaml
  - charts/ckan/Chart.yaml
path: charts/ckan/README.md
version: 1.0
date: 2026-04-01
-->
