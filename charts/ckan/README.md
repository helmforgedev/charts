<!-- SPDX-License-Identifier: Apache-2.0 -->
# CKAN

CKAN is an open-source data management system for powering data hubs and data portals.
It is used by governments, research institutions, and other organizations to manage and publish collections of data.

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
- **Configurable process ports** — CKAN, DataPusher, and Solr values change the
  listeners rather than only the Kubernetes metadata
- **Hardened runtime** — image-native non-root UIDs, seccomp, dropped
  capabilities, and disabled ServiceAccount token mounting
- **NetworkPolicy** — public CKAN ingress with internal-only component ports

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

```text
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
| `image.tag` | `2.12.0` | Image tag |
| `ckan.containerPort` | `5000` | CKAN uWSGI listener port |
| `ckan.uwsgiProcesses` | `2` | uWSGI worker processes |
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
| `networkPolicy.enabled` | `true` | Restrict CKAN, DataPusher, and Solr ingress |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount Kubernetes API credentials |
| `postgresql.enabled` | `true` | Enable PostgreSQL subchart |
| `redis.enabled` | `true` | Enable Redis subchart |

This chart deploys CKAN `2.12.0` with HelmForge PostgreSQL `2.1.1` and Redis `3.1.0`.
It intentionally does not keep `Chart.lock`; dependencies are resolved by the release workflow.

## Upgrade Notes

CKAN 2.12.0 is a minor application upgrade. Back up the CKAN database and
persistent storage, review the upstream 2.11.6 and 2.12.0 release notes, and
test extensions against CKAN 2.12 before production rollout. Keep the Solr,
PostgreSQL, and Redis services available while CKAN performs its upgrade steps.
The previous `redisConfig.external.url` value is replaced by structured host,
port, TLS, database, and Secret-backed password fields.

## Examples

See [production values](examples/production.yaml) for a hardened bundled
topology and [external datastores](examples/external-datastores.yaml) for a
DataStore-capable deployment.

### External Database

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
    existingSecret: ckan-database
    existingSecretPasswordKey: password
    existingSecretDatastoreReadPasswordKey: datastore-read-password
    sslMode: verify-full
```

### External Redis

```yaml
redis:
  enabled: false

redisConfig:
  mode: external
  external:
    host: redis.example.com
    port: 6379
    database: 0
    tls: true
    sslCertReqs: required
    existingSecret: ckan-redis
    existingSecretPasswordKey: redis-password
```

### Ingress

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

The chart configures DataStore read and write URLs but does not provision its
database or least-privilege roles. Prepare them according to the upstream
DataStore documentation before adding `datastore` and `datapusher` to the
plugin list. DataStore is supported only with `database.mode=external`.

## Security

Generated sysadmin, session, and JWT values are preserved during Helm upgrades.
For production, use `ckan.existingSecret` and externally managed datastore
credential Secrets so recovery does not depend on the Helm release Secret.

The CKAN image must update `/srv/app/ckan.ini` during startup, so its root
filesystem remains writable. Other hardening defaults remain enabled. Review
[security.md](docs/security.md) before restricting NetworkPolicy egress or
adding third-party plugins.

## Troubleshooting

Start with the CKAN logs, dependency endpoints, and recent events. A Ready web
pod does not validate DataPusher jobs, every extension, or a separate DataStore
database. The [operations guide](docs/operations.md) contains backup, restore,
dependency, and first-start checks.

## More Information

- [Chart design](DESIGN.md)
- [Configuration](docs/configuration.md)
- [Operations](docs/operations.md)
- [Security](docs/security.md)
- [Production values](examples/production.yaml)
- [External datastores](examples/external-datastores.yaml)

### Security Scan: `ckan`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **76.893936%** |

> Security posture acceptable.

<!-- @AI-METADATA
type: chart-readme
title: CKAN Helm Chart
description: CKAN open data portal with DataPusher, Solr, PostgreSQL, and Redis

keywords: ckan, data, portal, open-data, catalog, api, solr, postgresql, redis

purpose: Installation, configuration, and operational guide for the CKAN Helm chart
scope: charts/ckan

relations:
  - charts/ckan/values.yaml
  - charts/ckan/Chart.yaml
path: charts/ckan/README.md
version: 1.0
date: 2026-05-05
-->
