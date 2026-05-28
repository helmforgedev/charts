# Docmost

A Helm chart for deploying [Docmost](https://docmost.com/) on Kubernetes with PostgreSQL, Redis, local storage, Gateway API, Ingress, External Secrets, and optional S3-compatible object storage.

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
- **PostgreSQL subchart** bundled PostgreSQL `1.10.0` for default installs
- **Redis subchart** bundled Redis `1.6.14` for default installs
- **External services** support for managed PostgreSQL and Redis
- **Local or S3 storage** for uploaded files
- **Ingress support** configurable ingress with TLS
- **Gateway API HTTPRoute** support for clusters using Gateway API
- **External Secrets Operator** integration for secret material sourced outside Helm
- **Dual-stack service controls** through `service.ipFamilyPolicy` and `service.ipFamilies`
- **Optional backup CronJob** for PostgreSQL dumps uploaded to S3-compatible storage
- **Values schema** `values.schema.json` validates chart inputs and improves Artifact Hub rendering

## Important Notes

- this alpha chart currently supports `replicaCount=1` only
- Docmost requires PostgreSQL and Redis
- local storage uses `/app/data/storage`
- S3 mode uses the official `AWS_S3_*` environment variables documented by Docmost
- the default image tag is `0.90.0`, validated against the published `docmost/docmost:0.90.0` container image
- upstream telemetry can be disabled with `docmost.disableTelemetry=true`
- this chart intentionally does not keep `Chart.lock`; dependencies are resolved by the repository release workflow

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

### Gateway API

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: shared-gateway
      namespace: gateway-system
  hostnames:
    - docmost.example.com
```

### Dual-Stack Service

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

### External Secrets

```yaml
externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  data:
    - secretKey: database-password
      remoteRef:
        key: docmost/database
        property: password
```

### PostgreSQL Backup to S3

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://minio.example.internal
    bucket: backups
    prefix: docmost
    existingSecret: docmost-backup-s3
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `replicaCount` | `1` | Number of Docmost application pods |
| `image.repository` | `docker.io/docmost/docmost` | Docmost container image repository |
| `image.tag` | `0.90.0` | Docmost image tag |
| `docmost.appUrl` | `""` | External Docmost URL |
| `docmost.appSecret` | `""` | Application secret, auto-generated when empty |
| `docmost.jwtTokenExpiresIn` | `30d` | JWT expiration |
| `docmost.disableTelemetry` | `false` | Disable anonymous upstream telemetry collection |
| `database.mode` | `auto` | Database mode: `auto`, `external`, `postgresql` |
| `postgresql.enabled` | `true` | Deploy PostgreSQL subchart |
| `postgresql.auth.database` | `docmost` | PostgreSQL database created by the subchart |
| `postgresql.auth.username` | `docmost` | PostgreSQL application user created by the subchart |
| `redis.enabled` | `true` | Deploy Redis subchart |
| `redis.auth.enabled` | `true` | Enable Redis password authentication |
| `storage.mode` | `local` | File storage mode: `local` or `s3` |
| `storage.local.enabled` | `true` | Create or mount local uploads storage |
| `storage.local.size` | `10Gi` | Local uploads PVC size |
| `storage.s3.bucket` | `""` | S3 bucket name |
| `backup.enabled` | `false` | Enable the PostgreSQL backup CronJob |
| `backup.schedule` | `0 3 * * *` | Backup Cron schedule |
| `service.port` | `80` | Service port exposed by Kubernetes |
| `service.ipFamilyPolicy` | `""` | Kubernetes service IP family policy |
| `service.ipFamilies` | `[]` | Kubernetes service IP families |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `""` | Ingress class (`traefik`, `nginx`, etc.) |
| `gateway.enabled` | `false` | Render a Gateway API HTTPRoute |
| `gatewayAPI.enabled` | `false` | HelmForge-standard Gateway API alias |
| `externalSecrets.enabled` | `false` | Render an ExternalSecret for application credentials |

## Operations

The post-install notes include port-forward, application logs, PostgreSQL logs, Redis logs, and upgrade reminders.
For production upgrades, take a database backup first and verify the secret references used by `database.external.*`,
`redis.external.*`, `storage.s3.*`, and `backup.s3.*`.

## More Information

- [Architecture Notes](docs/architecture.md)
- [Examples](examples/simple.yaml)
- [Source code and full values reference](https://github.com/helmforgedev/charts/tree/main/charts/docmost)

<!-- @AI-METADATA
type: chart-readme
title: Docmost
description: Installation guide, values reference, and operational overview for the Docmost Helm chart

keywords: docmost, wiki, documentation, postgres, redis, s3, gateway-api, external-secrets, dual-stack, backup, helm

purpose: User-facing chart documentation with install instructions, examples, and values reference
scope: Chart

relations:
  - charts/docmost/docs/architecture.md
path: charts/docmost/README.md
version: 1.0
date: 2026-05-05
-->
