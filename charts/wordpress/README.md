# WordPress

A Helm chart for deploying [WordPress](https://wordpress.org/) on Kubernetes using the official [wordpress](https://hub.docker.com/_/wordpress) Docker image (Apache variant).

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install wordpress helmforge/wordpress
```

### OCI Registry

```bash
helm install wordpress oci://ghcr.io/helmforgedev/helm/wordpress
```

## Quick Start

```bash
helm install wordpress oci://ghcr.io/helmforgedev/helm/wordpress \
  --set wordpress.adminPassword=changeme \
  --set mysql.auth.password=dbpassword
```

## Features

- **Official WordPress Image** — Apache variant with PHP, ready for production
- **MySQL Subchart** — Bundled MySQL via HelmForge subchart dependency
- **External Database** — Connect to existing MySQL/MariaDB instances
- **Auto Database Detection** — Automatic mode selection (external vs subchart)
- **Persistent Storage** — PVC for WordPress files (themes, plugins, uploads)
- **Scheduled Backups** — CronJob-based mysqldump + wp-content archive to S3
- **Ingress Support** — Configurable ingress with TLS for HTTPS
- **PHP Configuration** — Custom php.ini via ConfigMap
- **Prometheus Metrics** — Apache exporter sidecar with ServiceMonitor
- **Wait-for-DB** — Init container ensures database is ready before WordPress starts
- **Secret Preservation** — Passwords preserved across upgrades via `lookup`

## Configuration

### Minimal (Simple Setup)

```yaml
wordpress:
  adminPassword: "change-me"

mysql:
  enabled: true
  auth:
    password: "db-password"
```

### Production (Full Setup)

```yaml
wordpress:
  siteUrl: "https://blog.example.com"
  adminEmail: admin@example.com
  configExtra: |
    define('WP_MEMORY_LIMIT', '256M');
    define('DISALLOW_FILE_EDIT', true);

admin:
  existingSecret: wordpress-admin

mysql:
  enabled: true
  auth:
    existingSecret: wordpress-mysql
  primary:
    persistence:
      size: 20Gi

persistence:
  enabled: true
  size: 10Gi

php:
  ini: |
    upload_max_filesize = 64M
    post_max_size = 64M
    memory_limit = 256M

ingress:
  enabled: true
  ingressClassName: traefik
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: blog.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: wordpress-tls
      hosts:
        - blog.example.com

backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: https://s3.amazonaws.com
    bucket: wordpress-backups
    existingSecret: wordpress-s3

resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: "1"
    memory: 512Mi
```

### External Database

```yaml
mysql:
  enabled: false

database:
  external:
    host: db.example.com
    port: 3306
    name: wordpress
    username: wordpress
    existingSecret: wordpress-db
    existingSecretPasswordKey: password
```

## Parameters

### Core Settings

| Key | Default | Description |
|-----|---------|-------------|
| `wordpress.siteUrl` | `""` | Full site URL (auto-detected from ingress if empty) |
| `wordpress.siteTitle` | `WordPress` | Site title |
| `wordpress.adminUser` | `admin` | Admin username |
| `wordpress.adminPassword` | `""` | Admin password (auto-generated if empty) |
| `wordpress.adminEmail` | `admin@example.com` | Admin email |
| `wordpress.tablePrefix` | `wp_` | Database table prefix |
| `wordpress.debug` | `false` | Enable WP_DEBUG |
| `wordpress.configExtra` | `""` | Extra PHP for wp-config.php |
| `wordpress.extraEnv` | `[]` | Extra environment variables |

### Database

| Key | Default | Description |
|-----|---------|-------------|
| `database.mode` | `auto` | Database mode (auto, external, mysql) |
| `database.external.host` | `""` | External database host |
| `database.external.port` | `3306` | External database port |
| `database.external.name` | `wordpress` | Database name |
| `database.external.username` | `wordpress` | Database username |
| `database.external.password` | `""` | Database password |
| `database.external.existingSecret` | `""` | Existing secret for DB password |

### MySQL Subchart

| Key | Default | Description |
|-----|---------|-------------|
| `mysql.enabled` | `true` | Deploy MySQL subchart |
| `mysql.architecture` | `standalone` | MySQL architecture |
| `mysql.auth.database` | `wordpress` | Database name |
| `mysql.auth.username` | `wordpress` | Database user |
| `mysql.auth.password` | `""` | Database password (auto-generated) |
| `mysql.primary.persistence.size` | `8Gi` | MySQL PVC size |

### Persistence

| Key | Default | Description |
|-----|---------|-------------|
| `persistence.enabled` | `true` | Enable persistent storage |
| `persistence.storageClass` | `""` | Storage class |
| `persistence.accessMode` | `ReadWriteOnce` | PVC access mode |
| `persistence.size` | `5Gi` | PVC size |
| `persistence.existingClaim` | `""` | Use existing PVC |

### Ingress

| Key | Default | Description |
|-----|---------|-------------|
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `""` | Ingress class (traefik, nginx, etc.) |
| `ingress.hosts` | `[]` | Ingress hosts and paths |
| `ingress.tls` | `[]` | TLS configuration |

### PHP

| Key | Default | Description |
|-----|---------|-------------|
| `php.ini` | `""` | Custom php.ini settings |

### Metrics

| Key | Default | Description |
|-----|---------|-------------|
| `metrics.enabled` | `false` | Enable apache-exporter sidecar |
| `metrics.image.tag` | `v1.0.8` | apache-exporter version |
| `metrics.port` | `9117` | Metrics port |
| `metrics.serviceMonitor.enabled` | `false` | Create ServiceMonitor |

### Backup

| Key | Default | Description |
|-----|---------|-------------|
| `backup.enabled` | `false` | Enable S3 backups |
| `backup.schedule` | `0 3 * * *` | Cron schedule |
| `backup.archivePrefix` | `wordpress` | Archive filename prefix |
| `backup.s3.endpoint` | `""` | S3-compatible endpoint |
| `backup.s3.bucket` | `""` | Target bucket |
| `backup.s3.prefix` | `wordpress` | Key prefix in bucket |
| `backup.s3.existingSecret` | `""` | Existing S3 credentials secret |
| `backup.database.mysqldumpArgs` | `--single-transaction...` | Extra mysqldump flags |

### Scheduling

| Key | Default | Description |
|-----|---------|-------------|
| `nodeSelector` | `{}` | Node selector |
| `tolerations` | `[]` | Tolerations |
| `affinity` | `{}` | Affinity rules |
| `terminationGracePeriodSeconds` | `30` | Shutdown grace period |

## Resources Generated

| Resource | Condition | Description |
|----------|-----------|-------------|
| Deployment | Always | WordPress + wait-for-db init container |
| Service | Always | HTTP port 80 (ClusterIP) |
| PersistentVolumeClaim | `persistence.enabled` | WordPress files |
| Secret (admin) | No `admin.existingSecret` | Admin password |
| Secret (database) | No external `existingSecret` | Database password |
| Secret (backup) | `backup.enabled`, no S3 `existingSecret` | S3 credentials |
| ConfigMap | `php.ini` set | Custom PHP configuration |
| Ingress | `ingress.enabled` | HTTPS access |
| CronJob | `backup.enabled` | mysqldump + wp-content archive to S3 |
| ConfigMap (backup) | `backup.enabled` | Backup shell scripts |
| ServiceAccount | `serviceAccount.create` | Dedicated SA |
| ServiceMonitor | `metrics.serviceMonitor.enabled` | Prometheus scrape config |

## Examples

- [Simple](examples/simple.yaml) — minimal with MySQL subchart
- [Production](examples/production.yaml) — ingress, backup, metrics, custom PHP
- [External DB](examples/external-db.yaml) — existing MySQL/MariaDB

## Architecture Guides

- [Database Modes](docs/database.md) — subchart vs external database
- [Backup & Restore](docs/backup.md) — S3 backup strategy and restore procedures

## Non-Goals

This chart intentionally does not support:

- **FPM variant** — Use the Apache variant for simplicity in Kubernetes
- **Multisite** — WordPress multisite requires complex URL rewriting
- **Horizontal scaling** — WordPress with shared storage has write contention issues
- **Built-in CDN** — Use a CDN plugin or external CDN service

<!-- @AI-METADATA
type: chart-readme
title: WordPress Helm Chart
description: Deploy WordPress on Kubernetes with MySQL, S3 backup, and Prometheus metrics
keywords: wordpress, cms, blog, php, mysql, helm, kubernetes, backup, metrics
purpose: Installation guide, configuration reference, and operational documentation for the wordpress Helm chart
scope: Chart
relations:
  - charts/wordpress/docs/database.md
  - charts/wordpress/docs/backup.md
  - charts/wordpress/values.yaml
path: charts/wordpress/README.md
version: 1.0
date: 2026-03-23
-->
