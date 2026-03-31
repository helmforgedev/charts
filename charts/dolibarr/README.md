# Dolibarr

A Helm chart for deploying [Dolibarr ERP/CRM](https://www.dolibarr.org/) on Kubernetes using the official [`dolibarr/dolibarr`](https://hub.docker.com/r/dolibarr/dolibarr) Docker image.

## Installation

### HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install dolibarr helmforge/dolibarr
```

### OCI Registry

```bash
helm install dolibarr oci://ghcr.io/helmforgedev/helm/dolibarr
```

## Quick Start

```bash
helm install dolibarr oci://ghcr.io/helmforgedev/helm/dolibarr \
  --set mysql.auth.password=dbpassword \
  --set dolibarr.companyName="Example Corp"
```

## Features

- **Official Dolibarr Image** — based on the official `dolibarr/dolibarr` container
- **MySQL Subchart** — bundled HelmForge MySQL dependency by default
- **External MySQL/MariaDB** — connect to an existing managed database
- **Auto Installation** — unattended setup through `DOLI_*` environment variables
- **Persistent Storage** — separate PVCs for `/var/www/documents` and `/var/www/html/custom`
- **Ingress Support** — configurable ingress with TLS for HTTPS access
- **Secret Preservation** — admin, runtime, and database secrets preserved across upgrades via `lookup`

## Configuration

### Minimal

```yaml
mysql:
  enabled: true
  auth:
    password: "change-me"

dolibarr:
  companyName: "Example Corp"
```

### Production

```yaml
dolibarr:
  siteUrl: "https://erp.example.com"
  companyName: "Example Corp"
  companyCountryCode: "US"
  enableModules: "societe,produit,service,propal,commande,facture"

mysql:
  enabled: true
  auth:
    existingSecret: dolibarr-mysql
  primary:
    persistence:
      size: 20Gi

persistence:
  documents:
    size: 20Gi
  custom:
    size: 5Gi

php:
  memoryLimit: 512M
  uploadMaxFilesize: 64M
  postMaxSize: 64M
  maxExecutionTime: "300"

ingress:
  enabled: true
  ingressClassName: traefik
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: erp.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: dolibarr-tls
      hosts:
        - erp.example.com
```

### External Database

```yaml
mysql:
  enabled: false

database:
  mode: external
  external:
    host: mariadb.example.com
    port: 3306
    name: dolibarr
    username: dolibarr
    existingSecret: dolibarr-db
    existingSecretPasswordKey: password
```

## Parameters

### Dolibarr

| Key | Default | Description |
|-----|---------|-------------|
| `dolibarr.siteUrl` | `""` | Full external URL (auto-detected from ingress if empty) |
| `dolibarr.companyName` | `Dolibarr` | Company name used during unattended setup |
| `dolibarr.companyCountryCode` | `US` | ISO country code used during unattended setup |
| `dolibarr.auth` | `dolibarr` | Authentication backend |
| `dolibarr.enableModules` | `""` | Comma-separated modules enabled on first boot |
| `dolibarr.installAuto` | `true` | Enable unattended installation |
| `dolibarr.initDemo` | `false` | Load demo data |
| `dolibarr.prod` | `true` | Enable production mode |
| `dolibarr.timezone` | `UTC` | PHP timezone |

### Admin

| Key | Default | Description |
|-----|---------|-------------|
| `admin.login` | `admin` | Admin login |
| `admin.password` | `""` | Admin password (auto-generated if empty) |
| `admin.existingSecret` | `""` | Existing secret for the admin password |

### Database

| Key | Default | Description |
|-----|---------|-------------|
| `database.mode` | `auto` | Database mode (`auto`, `external`, `mysql`) |
| `database.external.host` | `""` | External MySQL/MariaDB host |
| `database.external.port` | `3306` | External database port |
| `database.external.name` | `dolibarr` | Database name |
| `database.external.username` | `dolibarr` | Database username |
| `database.external.existingSecret` | `""` | Existing secret for DB password |
| `database.external.ssl` | `false` | Enable SSL for external DB connections |

### MySQL Subchart

| Key | Default | Description |
|-----|---------|-------------|
| `mysql.enabled` | `true` | Deploy MySQL as a subchart |
| `mysql.architecture` | `standalone` | MySQL architecture |
| `mysql.auth.database` | `dolibarr` | Database name |
| `mysql.auth.username` | `dolibarr` | Database username |
| `mysql.primary.persistence.size` | `8Gi` | MySQL PVC size |

### Persistence

| Key | Default | Description |
|-----|---------|-------------|
| `persistence.documents.enabled` | `true` | Persist `/var/www/documents` |
| `persistence.documents.size` | `8Gi` | Documents PVC size |
| `persistence.custom.enabled` | `true` | Persist `/var/www/html/custom` |
| `persistence.custom.size` | `2Gi` | Custom modules/themes PVC size |

### Ingress

| Key | Default | Description |
|-----|---------|-------------|
| `ingress.enabled` | `false` | Enable ingress |
| `ingress.ingressClassName` | `""` | Ingress class (`traefik`, `nginx`, etc.) |
| `ingress.hosts` | `[]` | Ingress hosts and paths |
| `ingress.tls` | `[]` | TLS configuration |

## Notes

- this chart intentionally supports **MySQL/MariaDB only** for automated setups
- PostgreSQL is not included because the official container workflow is not equivalent to the unattended MySQL path
- persist both `documents` and `custom` if you plan to keep generated artifacts, modules, or themes across upgrades
- built-in Dolibarr cron is intentionally not enabled by this first chart release because it still needs a stable Kubernetes validation path

## More Information

- [Database Modes](docs/database.md)
- [Source code and full values reference](https://github.com/helmforgedev/charts/tree/main/charts/dolibarr)

<!-- @AI-METADATA
type: chart-readme
title: Dolibarr
description: Installation guide, values reference, and operational overview for the Dolibarr Helm chart

keywords: dolibarr, erp, crm, php, mysql, mariadb, helm, kubernetes

purpose: User-facing chart documentation with install, examples, and values reference
scope: Chart

relations:
  - charts/dolibarr/docs/database.md
path: charts/dolibarr/README.md
version: 1.0
date: 2026-03-31
-->
