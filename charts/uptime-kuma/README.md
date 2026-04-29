# Uptime Kuma Helm Chart

Deploy [Uptime Kuma](https://uptime.kuma.pet) on Kubernetes using the official
[louislam/uptime-kuma](https://hub.docker.com/r/louislam/uptime-kuma) Docker image.
Self-hosted monitoring with HTTP/TCP/DNS/Ping checks, 90+ notification services, and customizable status pages.

## Features

- **20+ monitor types** — HTTP(s), TCP, Ping, DNS, Docker, WebSocket, and more
- **90+ notification services** — Telegram, Discord, Slack, Email, Pushover, and more
- **Status pages** — public status pages with custom domains
- **SQLite or MariaDB** — embedded SQLite (default) or MySQL subchart
- **External database** — connect to existing MariaDB instances
- **Scheduled backups** — SQLite tar or mysqldump with S3 upload
- **Ingress support** — TLS with cert-manager
- **2FA** — built-in two-factor authentication

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install uptime-kuma helmforge/uptime-kuma -f values.yaml
```

**OCI registry:**

```bash
helm install uptime-kuma oci://ghcr.io/helmforgedev/helm/uptime-kuma -f values.yaml
```

## Basic Example (SQLite)

```yaml
# values.yaml — default values are sufficient
# SQLite is used by default, no database configuration needed
```

After deploying, access the setup wizard:

```bash
kubectl port-forward svc/<release>-uptime-kuma 3001:80
# Open http://localhost:3001
```

## MariaDB Mode

```yaml
database:
  type: mariadb

mysql:
  enabled: true
  auth:
    password: "change-me"
```

## External Database

```yaml
database:
  type: mariadb
  external:
    host: mariadb.example.com
    name: uptime_kuma
    username: uptime_kuma
    existingSecret: uptime-kuma-db-credentials

mysql:
  enabled: false
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `uptimeKuma.port` | `3001` | Application port |
| `database.type` | `sqlite` | Database type (sqlite, mariadb) |
| `mysql.enabled` | `false` | Deploy MySQL subchart |
| `persistence.enabled` | `true` | Enable persistence for /app/data |
| `persistence.size` | `2Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `backup.enabled` | `false` | Enable S3 backups |
| `service.port` | `80` | Service port |

## More Information

- [Database configuration](docs/database.md)
- [Backup configuration](docs/backup.md)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/uptime-kuma)

<!-- @AI-METADATA
@description: README for the Uptime Kuma Helm chart
@type: chart-readme
@chart: uptime-kuma
@path: charts/uptime-kuma/README.md
@date: 2026-03-23
@relations:
  - charts/uptime-kuma/values.yaml
  - charts/uptime-kuma/docs/database.md
  - charts/uptime-kuma/docs/backup.md
-->
