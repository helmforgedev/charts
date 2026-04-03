# Castopod Helm Chart

A Helm chart for [Castopod](https://castopod.org), an open-source podcast hosting platform that supports the Fediverse. Deploys Castopod with MariaDB (required) and optional Redis caching.

## Features

- FrankenPHP-based all-in-one container (web server + PHP)
- MariaDB subchart or external database support
- Optional Redis subchart for caching
- Persistent storage for uploads, cache, logs, and sessions
- S3-compatible backup for the writable directory
- Auto-generated analytics salt
- Configurable health probes on `/health`
- Ingress support with TLS

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install castopod helmforge/castopod
```

### OCI

```bash
helm install castopod oci://ghcr.io/helmforgedev/helm/castopod
```

## Configuration

### Base URL

Castopod requires a base URL for proper operation:

```yaml
castopod:
  baseURL: "https://podcast.example.com"
```

### External Database

To use an external MariaDB instead of the subchart:

```yaml
mariadb:
  enabled: false

database:
  external:
    host: db.example.com
    port: "3306"
    name: castopod
    username: castopod
    password: "your-password"
```

### Redis Cache

Enable Redis for improved caching performance:

```yaml
redis:
  enabled: true
```

### Ingress

```yaml
ingress:
  enabled: true
  ingressClassName: traefik  # or nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  hosts:
    - host: podcast.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - podcast.example.com
      secretName: castopod-tls
```

### Persistence

Persistent storage is enabled by default for `/var/www/html/writable`:

```yaml
persistence:
  enabled: true
  size: 10Gi
  accessMode: ReadWriteOnce
  # storageClass: ""
```

### S3 Backup

Enable scheduled backups of the writable directory to S3-compatible storage:

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  archivePrefix: castopod
  s3:
    endpoint: "https://s3.example.com"
    bucket: "castopod-backups"
    accessKey: "your-access-key"
    secretKey: "your-secret-key"
```

## Default Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `docker.io/castopod/castopod` | Container image |
| `image.tag` | `""` (appVersion) | Image tag |
| `castopod.baseURL` | `""` | Application base URL |
| `castopod.port` | `80` | FrankenPHP port |
| `analytics.salt` | `""` (auto-generated) | Analytics salt (64 chars) |
| `persistence.enabled` | `true` | Enable persistent storage |
| `persistence.size` | `10Gi` | PVC size |
| `service.type` | `ClusterIP` | Service type |
| `service.port` | `80` | Service port |
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `traefik` | Ingress class |
| `mariadb.enabled` | `true` | Deploy MariaDB subchart |
| `mariadb.auth.database` | `castopod` | Database name |
| `mariadb.auth.username` | `castopod` | Database username |
| `redis.enabled` | `false` | Deploy Redis subchart |
| `backup.enabled` | `false` | Enable S3 backups |
| `backup.schedule` | `0 3 * * *` | Backup cron schedule |

## Links

- [Castopod Documentation](https://docs.castopod.org)
- [Castopod Source](https://code.castopod.org/adaures/castopod)
- [Docker Hub](https://hub.docker.com/r/castopod/castopod)

<!-- @AI-METADATA
type: chart-readme
path: charts/castopod/README.md
date: 2026-04-03
description: Castopod Helm chart documentation with install, configuration, and values reference
relations:
  - charts/castopod/values.yaml
  - charts/castopod/Chart.yaml
-->
