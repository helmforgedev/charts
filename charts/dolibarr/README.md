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
- **Gateway API Support** — optional HTTPRoute for clusters using Gateway API
- **S3 Backups** — optional mysqldump CronJob for S3-compatible storage
- **Secret Preservation** — admin, runtime, and database secrets preserved across upgrades via `lookup`
- **Network Isolation** — ingress is limited to the named Dolibarr HTTP port by default
- **Runtime Validation** — the chart verifies the real Apache listener and a Dolibarr HTTP response on k3d

## Architecture

The chart runs one Dolibarr Deployment because its documents and custom-module
volumes default to `ReadWriteOnce`. A named Service port routes to Apache, whose
real listener is configured from `containerPorts.http`. The application connects
either to the bundled HelmForge MySQL StatefulSet or to an operator-managed
MySQL/MariaDB endpoint. See [DESIGN.md](DESIGN.md) for trust boundaries and
design decisions.

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
  standalone:
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

### Examples

Ready-to-adapt values files are available for common deployment models:

- [Simple bundled MySQL](examples/simple.yaml)
- [Production with TLS and backups](examples/production.yaml)
- [External database](examples/external-db.yaml)

To validate an example before applying it:

```bash
helm template dolibarr . -f examples/production.yaml
```

## Parameters

## Upgrade to 24.0.2

Dolibarr 24.0.2 is a patch release on the 24.0 line. It fixes authorization,
failed-upload reporting, API-call counting, SQL-prefix handling, table
creation and multiple business workflows. Back up the database and both the
documents and custom PVCs before upgrading. The 24.0 major-upgrade cautions
still apply: review removed or renamed modules, hooks, configuration variables
and integrations, then test the upgrade in staging before reusing production
storage. In particular, the Login API is disabled by default in 24.0 unless
`API_ENABLE_LOGIN_API` is enabled, so integrations that use it can stop
authenticating.

[Review the official Dolibarr 24.0.2 release notes](https://github.com/Dolibarr/dolibarr/releases/tag/24.0.2)
and the [24.0.0 migration notes](https://github.com/Dolibarr/dolibarr/releases/tag/24.0.0)
before production rollout.

### Application

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
| `containerPorts.http` | `80` | Apache listener and pod HTTP port |

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
| `mysql.standalone.persistence.size` | `8Gi` | MySQL PVC size |
| `mysql.startupProbe.initialDelaySeconds` | `30` | MySQL startup probe delay used to avoid false-positive bootstrap warnings |

When upgrading from chart releases that used `mysql.primary.*`, migrate those
values to `mysql.standalone.*`. The chart fails fast if `mysql.primary` is still
present so persistence and resource settings are not silently ignored by the
HelmForge MySQL 2.x dependency.

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

### Network Policy and Service Account

| Key | Default | Description |
|-----|---------|-------------|
| `networkPolicy.enabled` | `true` | Restrict inbound traffic to the named HTTP port |
| `networkPolicy.ingressFrom` | `[]` | Optional ingress peers; empty permits the HTTP port from any namespace |
| `serviceAccount.create` | `false` | Create a dedicated ServiceAccount |
| `serviceAccount.automountServiceAccountToken` | `false` | Mount a Kubernetes API token in the application pod |

## Security

The pod does not receive a Kubernetes API token by default. A NetworkPolicy
selects only the Dolibarr workload and exposes only its named HTTP port. Secrets
generated by the chart are preserved with `lookup`, and their rendered checksum
is included in the pod template so intentional value changes trigger a rollout.

The official image must start as root to perform first-run ownership and Apache
setup, and it requires writable application paths. Consequently,
`runAsNonRoot` and `readOnlyRootFilesystem` are not safe chart defaults. Apply a
stricter `securityContext` only after validating a compatible derivative image
and storage layout. TLS termination, external-database controls, Secret rotation,
and egress restrictions remain operator responsibilities.

### Security Scan: `dolibarr`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **87.878784%** |
| MITRE | **100.00%** |
| NSA | **82.50%** |
| SOC2 | **90.00%** |

The remaining findings reflect the official Dolibarr container's root-based
bootstrap and writable application filesystem.

## Troubleshooting

If the pod remains in `Init`, inspect the `wait-for-db` init-container logs and
verify the selected database hostname, port, and Secret key. If readiness fails,
confirm that `containerPorts.http` is free and inspect the generated Apache files:

```bash
kubectl logs deploy/dolibarr -c wait-for-db
kubectl logs deploy/dolibarr -c dolibarr
kubectl exec deploy/dolibarr -c dolibarr -- grep -E '^(Listen|<VirtualHost)' \
  /etc/apache2/ports.conf /etc/apache2/sites-available/000-default.conf
```

For missing uploads or modules, verify that both PVCs are `Bound` and that the
corresponding `existingClaim` names are correct. For failed backups, inspect the
CronJob-created Job and confirm the S3 endpoint, bucket, and credential Secret.

## Notes

- this chart intentionally supports **MySQL/MariaDB only** for automated setups
- PostgreSQL is not included because the official container workflow is not equivalent to the unattended MySQL path
- persist both `documents` and `custom` if you plan to keep generated artifacts, modules, or themes across upgrades
- built-in Dolibarr cron is intentionally not enabled by this first chart release because it still needs a stable Kubernetes validation path
- the default startup probe delay accounts for the initial database import performed by the official container on a fresh deployment

## More Information

- [Database Modes](docs/database.md)
- [Chart Design](DESIGN.md)
- [Source code and full values reference](https://github.com/helmforgedev/charts/tree/main/charts/dolibarr)

<!-- @AI-METADATA
type: chart-readme
title: Dolibarr
description: Installation guide, values reference, and operational overview for the Dolibarr Helm chart

keywords: dolibarr, erp, crm, php, mysql, mariadb, helm, kubernetes

purpose: User-facing chart documentation with install, examples, and values reference
scope: Chart

relations:
  - charts/dolibarr/DESIGN.md
  - charts/dolibarr/docs/database.md
path: charts/dolibarr/README.md
version: 1.0
date: 2026-03-31
-->
