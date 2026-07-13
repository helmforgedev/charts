# Ghost Helm Chart

Deploy [Ghost](https://ghost.org) on Kubernetes using the official
[ghost](https://hub.docker.com/_/ghost) container image. A modern publishing platform
for building blogs, newsletters, and membership-based content with built-in monetization.

## Features

- **MySQL backend** — bundled via HelmForge subchart or external database
- **Content persistence** — images, media, and files on PVC
- **S3 backup** — scheduled content backups to S3-compatible storage
- **Headless CMS** — REST and Content API for headless usage
- **Memberships** — built-in subscriptions, newsletters, and payments
- **Ingress support** — TLS with cert-manager
- **Gateway API support** — optional HTTPRoute for modern ingress stacks
- **External Secrets support** — optional database password synchronization

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install ghost helmforge/ghost -f values.yaml
```

**OCI registry:**

```bash
helm install ghost oci://ghcr.io/helmforgedev/helm/ghost -f values.yaml
```

## Basic Example

```yaml
# values.yaml
ghost:
  url: "https://blog.example.com"
```

After deploying:

```bash
kubectl port-forward svc/<release>-ghost 2368:80
# Open http://localhost:2368/ghost to set up admin account
```

## External MySQL

```yaml
mysql:
  enabled: false

database:
  external:
    host: "mysql.example.com"
    name: ghost
    username: ghost
    password: "secure-password"
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `ghost.url` | `""` | Public URL of the Ghost instance |
| `image.tag` | `6.52.1` | Ghost image tag |
| `mysql.enabled` | `true` | Deploy MySQL subchart |
| `mysql.image.tag` | `8.4.7` | MySQL image tag pinned to the Ghost-supported MySQL 8 major |
| `persistence.enabled` | `true` | Enable content persistence |
| `persistence.size` | `10Gi` | Content PVC size |
| `backup.enabled` | `false` | Enable S3 content backups |
| `ingress.enabled` | `false` | Enable ingress |
| `gateway.enabled` | `false` | Enable Gateway API HTTPRoute |
| `externalSecrets.enabled` | `false` | Render ExternalSecret for database password |

## Upgrade Notes

Ghost `6.52.1` is the current upstream patch release and fixes link selection
in the automations email editor. Review the upstream Ghost release notes before
upgrading production sites, take a content and database backup, and verify
themes, custom integrations, newsletter flows, comments, and member signup
paths in staging before reusing existing PVCs.

## S3 Backup

```yaml
backup:
  enabled: true
  schedule: "0 3 * * *"
  s3:
    endpoint: "https://s3.example.com"
    bucket: ghost-backups
    accessKey: "minioadmin"
    secretKey: "minioadmin"
```

## Limitations

- **Single instance** — Ghost does not support horizontal scaling out of the box
- **MySQL only** — Ghost requires MySQL 8; PostgreSQL is not supported. The bundled HelmForge MySQL dependency is kept on MySQL 8 through `mysql.image.tag`.

### Security Scan: `ghost`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **86.580086%** |

> Security posture acceptable.

## More Information

- [Chart design](DESIGN.md)
- [Database modes](docs/database.md)
- [Ghost documentation](https://ghost.org/docs/)
- [Source code](https://github.com/helmforgedev/charts/tree/main/charts/ghost)
