# Listmonk Helm Chart

Self-hosted newsletter and mailing list manager for Kubernetes.

[Listmonk](https://listmonk.app) is a high-performance, self-hosted newsletter and mailing list manager. It comes as a single binary with a built-in web UI for managing subscribers, campaigns, templates, and transactional emails.

## Features

- Bundled PostgreSQL via HelmForge subchart or external database support
- Automatic database initialization and migration on startup
- Persistent storage for media uploads
- Configurable ingress with TLS support
- Built-in PostgreSQL backup CronJob with S3 upload
- First-access setup wizard for Super Admin account creation
- SMTP configuration through the admin UI after installation

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install listmonk helmforge/listmonk
```

## Quick Start

### Default install (bundled PostgreSQL)

```bash
helm install listmonk helmforge/listmonk
```

### External PostgreSQL

```bash
helm install listmonk helmforge/listmonk \
  --set postgresql.enabled=false \
  --set database.mode=external \
  --set database.external.host=pg.example.com \
  --set database.external.password=changeme
```

### With ingress

```bash
helm install listmonk helmforge/listmonk \
  --set ingress.enabled=true \
  --set ingress.ingressClassName=traefik \
  --set "ingress.hosts[0].host=listmonk.example.com" \
  --set "ingress.hosts[0].paths[0].path=/" \
  --set "ingress.hosts[0].paths[0].pathType=Prefix"
```

## Configuration

SMTP and most application settings are configured through the Listmonk admin UI after installation at **Settings > SMTP**. The Helm chart handles infrastructure-level configuration (database, storage, ingress, probes).

### Admin Setup

On first access, Listmonk displays a setup wizard where you create a Super Admin account. This is handled entirely through the web UI — the chart does not manage admin credentials.

### Database Initialization

The chart automatically runs `--install --idempotent --yes` and `--upgrade --yes` as init containers before the main application starts. This handles both fresh installs and upgrades.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `replicaCount` | int | `1` | Number of replicas |
| `image.repository` | string | `docker.io/listmonk/listmonk` | Image repository |
| `image.tag` | string | `""` | Image tag (defaults to appVersion) |
| `image.pullPolicy` | string | `IfNotPresent` | Pull policy |
| `listmonk.extraEnv` | list | `[]` | Additional environment variables |
| `database.mode` | string | `auto` | Database mode: `auto`, `external`, `postgresql` |
| `database.external.host` | string | `""` | External PostgreSQL hostname |
| `database.external.port` | int | `5432` | External PostgreSQL port |
| `database.external.name` | string | `listmonk` | External database name |
| `database.external.username` | string | `listmonk` | External database username |
| `database.external.password` | string | `""` | External database password |
| `database.external.sslMode` | string | `disable` | PostgreSQL SSL mode |
| `database.external.existingSecret` | string | `""` | Existing secret for database password |
| `postgresql.enabled` | bool | `true` | Deploy PostgreSQL subchart |
| `postgresql.auth.database` | string | `listmonk` | PostgreSQL database name |
| `postgresql.auth.username` | string | `listmonk` | PostgreSQL username |
| `storage.enabled` | bool | `true` | Enable persistent uploads storage |
| `storage.size` | string | `5Gi` | Uploads PVC size |
| `storage.existingClaim` | string | `""` | Use existing PVC |
| `backup.enabled` | bool | `false` | Enable backup CronJob |
| `backup.schedule` | string | `0 3 * * *` | Backup cron schedule |
| `service.type` | string | `ClusterIP` | Service type |
| `service.port` | int | `80` | Service port |
| `ingress.enabled` | bool | `false` | Enable ingress |
| `ingress.ingressClassName` | string | `""` | Ingress class (`traefik`, `nginx`, etc.) |
| `ingress.hosts` | list | `[]` | Ingress hosts |
| `ingress.tls` | list | `[]` | Ingress TLS configuration |

## Backup

Enable PostgreSQL backups to S3-compatible storage:

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: my-backups
    prefix: listmonk
    accessKey: AKIAIOSFODNN7EXAMPLE
    secretKey: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

Or use an existing secret:

```yaml
backup:
  enabled: true
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: my-backups
    existingSecret: my-s3-credentials
```

<!-- @AI-METADATA
type: chart-readme
title: Listmonk Helm Chart
description: Helm chart for deploying Listmonk newsletter and mailing list manager on Kubernetes

keywords: listmonk, newsletter, mailing-list, email, helm, kubernetes

purpose: Installation and configuration guide for the Listmonk Helm chart
scope: Chart Documentation

relations:
  - charts/listmonk/values.yaml
  - charts/listmonk/Chart.yaml
path: charts/listmonk/README.md
version: 1.0
date: 2026-04-03
-->
