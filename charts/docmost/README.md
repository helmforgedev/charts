# Docmost

A Helm chart for deploying [Docmost](https://docmost.com/) on Kubernetes with PostgreSQL, Redis, local storage, and optional S3-compatible object storage.

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install docmost helmforge/docmost
```

### OCI Registry

```bash
helm install docmost oci://ghcr.io/helmforgedev/helm/docmost
```

## Features

- **Official Docmost image** based on `docmost/docmost`
- **PostgreSQL subchart** bundled PostgreSQL for default installs
- **Redis subchart** bundled Redis for default installs
- **External services** support for managed PostgreSQL and Redis
- **Local or S3 storage** for uploaded files
- **Ingress support** configurable ingress with TLS
- **Values schema** `values.schema.json` validates chart inputs and improves Artifact Hub rendering

## Important Notes

- this alpha chart currently supports `replicaCount=1` only
- Docmost requires PostgreSQL and Redis
- local storage uses `/app/data/storage`
- S3 mode uses the official `AWS_S3_*` environment variables documented by Docmost
- Docker Hub exposed `0.71.0` while the official GitHub releases page showed `v0.70.3`, so the chart pins `0.70.3` under the repository release-validation rule

## Quick Start

```bash
helm install docmost oci://ghcr.io/helmforgedev/helm/docmost \
  --set ingress.enabled=true \
  --set ingress.ingressClassName=traefik \
  --set ingress.hosts[0].host=docmost.example.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix
```

## Example Configurations

### Basic Install

```yaml
docmost:
  appUrl: https://docmost.example.com

ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: docmost.example.com
      paths:
        - path: /
          pathType: Prefix
```

### External Services with S3

```yaml
database:
  mode: external
  external:
    host: postgres.example.internal
    existingSecret: docmost-db

postgresql:
  enabled: false

redis:
  enabled: false
  external:
    host: redis.example.internal
    existingSecret: docmost-redis

storage:
  mode: s3
  s3:
    bucket: docmost
    endpoint: https://minio.example.internal
    existingSecret: docmost-s3
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `replicaCount` | `1` | Number of Docmost application pods |
| `docmost.appUrl` | `""` | External Docmost URL |
| `docmost.jwtTokenExpiresIn` | `30d` | JWT expiration |
| `database.mode` | `auto` | Database mode: `auto`, `external`, `postgresql` |
| `postgresql.enabled` | `true` | Deploy PostgreSQL subchart |
| `redis.enabled` | `true` | Deploy Redis subchart |
| `storage.mode` | `local` | File storage mode: `local` or `s3` |
| `storage.local.size` | `10Gi` | Local uploads PVC size |
| `storage.s3.bucket` | `""` | S3 bucket name |
| `service.port` | `80` | Service port exposed by Kubernetes |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `""` | Ingress class (`traefik`, `nginx`, etc.) |

## More Information

- [Architecture Notes](docs/architecture.md)
- [Examples](examples/simple.yaml)
- [Source code and full values reference](https://github.com/helmforgedev/charts/tree/main/charts/docmost)

<!-- @AI-METADATA
type: chart-readme
title: Docmost
description: Installation guide, values reference, and operational overview for the Docmost Helm chart

keywords: docmost, wiki, documentation, postgres, redis, s3, helm

purpose: User-facing chart documentation with install instructions, examples, and values reference
scope: Chart

relations:
  - charts/docmost/docs/architecture.md
path: charts/docmost/README.md
version: 1.0
date: 2026-04-01
-->
