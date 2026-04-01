# Komga Helm Chart

Deploy [Komga](https://komga.org) on Kubernetes — a media server for comics, mangas, BDs, magazines, and eBooks with OPDS support.

## Features

- **SQLite Database** — zero database configuration, persistent via PVC
- **Dual Persistent Volumes** — separate PVCs for config (`/config`) and library data (`/data`)
- **Java Tool Options** — configurable JVM tuning via `JAVA_TOOL_OPTIONS`
- **Timezone Support** — configurable via `TZ` environment variable
- **Ingress** — optional with TLS and cert-manager support
- **S3 Backup** — scheduled CronJob with consistent SQLite exports and config archive upload

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install komga helmforge/komga
```

### OCI Registry

```bash
helm install komga oci://ghcr.io/helmforgedev/helm/komga
```

## Quick Start

```yaml
persistence:
  config:
    enabled: true
    size: 2Gi
  data:
    enabled: true
    size: 100Gi
```

After deploying, port-forward to access the web interface and create your admin account:

```bash
kubectl port-forward svc/<release>-komga 25600:80
```

## Production Example

```yaml
komga:
  timezone: "America/Sao_Paulo"
  javaToolOptions: "-Xmx2g -XX:+UseG1GC"
  sessionTimeout: "7d"

persistence:
  config:
    size: 5Gi
  data:
    size: 500Gi

ingress:
  enabled: true
  ingressClassName: traefik
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  hosts:
    - host: komga.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - komga.example.com
      secretName: komga-tls

backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: my-backups
    prefix: komga
    existingSecret: komga-s3-credentials
```

## Values

### Image

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `gotson/komga` | Image repository |
| `image.tag` | `""` (appVersion) | Image tag |
| `image.pullPolicy` | `IfNotPresent` | Pull policy |

### Komga Configuration

| Key | Default | Description |
|-----|---------|-------------|
| `komga.port` | `25600` | Container port |
| `komga.contextPath` | `/` | Base URL path for reverse proxy |
| `komga.sessionTimeout` | `30m` | Session timeout |
| `komga.timezone` | `UTC` | Timezone |
| `komga.javaToolOptions` | `""` | Value passed to `JAVA_TOOL_OPTIONS` |
| `komga.javaMemory` | `""` | Deprecated alias for `komga.javaToolOptions` |
| `komga.extraEnv` | `[]` | Extra environment variables |

### Persistence

| Key | Default | Description |
|-----|---------|-------------|
| `persistence.config.enabled` | `true` | Persist /config (database) |
| `persistence.config.size` | `2Gi` | Config PVC size |
| `persistence.config.existingClaim` | `""` | Existing config PVC |
| `persistence.data.enabled` | `true` | Persist /data (libraries) |
| `persistence.data.size` | `50Gi` | Data PVC size |
| `persistence.data.existingClaim` | `""` | Existing data PVC |

### Service

| Key | Default | Description |
|-----|---------|-------------|
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `80` | Service port |

### Ingress

| Key | Default | Description |
|-----|---------|-------------|
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `traefik` | Ingress class (`traefik`, `nginx`, etc.) |
| `ingress.hosts` | `[]` | Ingress host rules |
| `ingress.tls` | `[]` | TLS configuration |

### Backup

| Key | Default | Description |
|-----|---------|-------------|
| `backup.enabled` | `false` | Enable S3 backup CronJob |
| `backup.schedule` | `0 2 * * *` | Cron schedule |
| `backup.includeLogs` | `true` | Include `/config/logs` when present |
| `backup.s3.endpoint` | `""` | S3 endpoint URL |
| `backup.s3.bucket` | `""` | S3 bucket |
| `backup.s3.accessKey` | `""` | S3 access key |
| `backup.s3.secretKey` | `""` | S3 secret key |
| `backup.s3.existingSecret` | `""` | Existing S3 credentials secret |

## Backup Behavior

The backup CronJob exports each SQLite database found in `/config` using `sqlite3 VACUUM INTO`, then packages those exported databases together with top-level application config files and optional logs before uploading the archive to S3. Search indexes are intentionally excluded because Komga can rebuild them.

## Architecture

Komga runs as a single Deployment with a Java-based server on port 25600. It uses SQLite for its database (stored in `/config`) and serves comic/manga libraries from `/data`.

The chart creates two separate PVCs:

- **config** — small volume for SQLite database and application settings
- **data** — large volume for comic/manga library files

## Documentation

- [Backup Guide](docs/backup.md)
- [Komga Official Docs](https://komga.org/docs)

<!-- @AI-METADATA
type: chart-readme
title: Komga Helm Chart
description: Komga media server chart with SQLite persistence, ingress, and S3 backup
keywords: komga, comics, manga, media-server, opds, helm
purpose: Installation guide, values reference, and architecture overview
scope: Chart
relations:
  - charts/komga/values.yaml
  - charts/komga/docs/backup.md
path: charts/komga/README.md
version: 1.0
date: 2026-03-23
-->
