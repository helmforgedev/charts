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
- **Gateway API support** — optional HTTPRoute rendering for dashboard and status pages
- **External Secrets support** — optional ExternalSecret resources for database, backup, or integration credentials
- **Dual-stack Service support** — optional `ipFamilyPolicy` and `ipFamilies`
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

The optional local database path uses the HelmForge MySQL subchart `2.0.0`
as a MariaDB-compatible backend.

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

## Gateway API

```yaml
gatewayAPI:
  enabled: true
  httpRoutes:
    - name: web
      parentRefs:
        - name: public
          namespace: gateway-system
      hostnames:
        - status.example.com
```

## External Secrets

Use External Secrets Operator to materialize Secrets, then point chart values at those target Secrets.

```yaml
database:
  type: mariadb
  external:
    host: mariadb.example.com
    existingSecret: uptime-kuma-db

externalSecrets:
  enabled: true
  items:
    - name: database
      spec:
        secretStoreRef:
          name: platform-secrets
          kind: ClusterSecretStore
        target:
          name: uptime-kuma-db
          creationPolicy: Owner
        data:
          - secretKey: password
            remoteRef:
              key: uptime-kuma/database
              property: password
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `docker.io/louislam/uptime-kuma` | Uptime Kuma container image |
| `image.tag` | `2.4.0` | Uptime Kuma image tag |
| `uptimeKuma.port` | `3001` | Application port |
| `database.type` | `sqlite` | Database type (sqlite, mariadb) |
| `mysql.enabled` | `false` | Deploy MySQL subchart (`helmforge/mysql` `2.0.0`) |
| `persistence.enabled` | `true` | Enable persistence for /app/data |
| `persistence.size` | `2Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `backup.enabled` | `false` | Enable S3 backups |
| `service.port` | `80` | Service port |
| `service.ipFamilyPolicy` | omitted | Optional Service IP family policy for dual-stack clusters |
| `gatewayAPI.enabled` | `false` | Enable Gateway API HTTPRoute rendering |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resources |

## Upgrade Notes

Uptime Kuma `2.4.0` adds notification providers, incident RSS support, monitor
improvements, bug fixes, and an authenticated admin security fix. The default
`database.type=sqlite` path remains aligned with upstream behavior. Keep
persistence enabled for production SQLite deployments and back up `/app/data`
before upgrading live instances.

## More Information

- [Database configuration](docs/database.md)
- [Backup configuration](docs/backup.md)
- [Chart design](DESIGN.md)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/uptime-kuma)

### Security Scan: `uptime-kuma`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **80.30303%** |

Security posture acceptable.

<!-- @AI-METADATA
@description: README for the Uptime Kuma Helm chart
@type: chart-readme
@chart: uptime-kuma
@path: charts/uptime-kuma/README.md
@date: 2026-03-23
@relations:
  - charts/uptime-kuma/values.yaml
  - charts/uptime-kuma/DESIGN.md
  - charts/uptime-kuma/docs/database.md
  - charts/uptime-kuma/docs/backup.md
-->
