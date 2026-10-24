# Wallabag Helm Chart

Deploy [Wallabag](https://wallabag.org) on Kubernetes with the official
[wallabag/wallabag](https://hub.docker.com/r/wallabag/wallabag) image.
Wallabag is a self-hosted read-it-later application: save articles from the
web, strip distractions, and read them in the browser, mobile apps, or e-readers.

## Features

- **Working first install**: a setup init container installs the Wallabag
  schema on first start and runs Doctrine migrations on every upgrade
- **Initial super-admin from a Secret**: username, email, and a generated or
  supplied password; no `wallabag/wallabag` default account is left behind
- **PostgreSQL backend**: HelmForge PostgreSQL subchart or an external server
- **Optional Redis**: subchart or external instance for the asynchronous import queue
- **Stable secrets**: the Symfony secret and admin password survive `helm upgrade`
- **Configurable listener**: `wallabag.port` changes the real nginx listener
- **Exposure**: Ingress or Gateway API HTTPRoutes
- **S3 backups**: scheduled `pg_dump` archives uploaded to S3-compatible storage
- **Hardened defaults**: no privilege escalation, minimal capabilities,
  `RuntimeDefault` seccomp, no ServiceAccount token

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install wallabag helmforge/wallabag \
  --set wallabag.domainName=https://wallabag.example.com
```

**OCI registry:**

```bash
helm install wallabag oci://ghcr.io/helmforgedev/helm/wallabag \
  --set wallabag.domainName=https://wallabag.example.com
```

## Quick Start

```bash
kubectl rollout status deploy/wallabag-wallabag --timeout=300s
kubectl get secret wallabag-wallabag-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl port-forward svc/wallabag-wallabag 8080:80
```

Open `http://localhost:8080/` and log in as `wallabag` with the password above.
Resource names follow `<release>-wallabag`, so the release `wallabag` creates
`wallabag-wallabag`.

## Architecture

The pod runs a `setup` init container and the `wallabag` container, both from
the same image. The setup container waits for PostgreSQL, installs the schema
when `wallabag_internal_setting` is missing, configures the initial
super-admin once, and applies pending migrations on later starts. The main
container runs nginx and PHP-FPM under the upstream `s6` supervisor. See
[DESIGN.md](DESIGN.md) for the full design and its boundaries.

## Configuration

### Application

| Key | Default | Description |
|-----|---------|-------------|
| `wallabag.domainName` | `https://wallabag.example.com` | Public URL, scheme and host without a trailing slash |
| `wallabag.serverName` | `Wallabag` | Instance name shown in the UI and API |
| `wallabag.port` | `80` | nginx listener inside the container |
| `wallabag.registration` | `false` | Allow public user registration |
| `wallabag.secret` | `""` | Symfony secret; generated once when empty |
| `wallabag.existingSecret` | `""` | Existing Secret with the Symfony secret |
| `wallabag.existingSecretKey` | `symfony-secret` | Key in `wallabag.existingSecret` |
| `wallabag.admin.username` | `wallabag` | Initial super-admin username |
| `wallabag.admin.email` | `wallabag@example.com` | Initial super-admin email |
| `wallabag.admin.password` | `""` | Initial super-admin password; generated once when empty |
| `wallabag.admin.existingSecret` | `""` | Existing Secret with the admin password |
| `wallabag.admin.existingSecretPasswordKey` | `admin-password` | Key in `wallabag.admin.existingSecret` |
| `wallabag.extraEnv` | `[]` | Extra environment variables for the Wallabag container |
| `setup.enabled` | `true` | Run the schema install and migration init container |
| `setup.databaseWaitTimeoutSeconds` | `300` | Seconds to wait for PostgreSQL |
| `setup.resources` | `{}` | Resources for the setup container |

### Database and Redis

| Key | Default | Description |
|-----|---------|-------------|
| `postgresql.enabled` | `true` | Deploy the HelmForge PostgreSQL subchart |
| `postgresql.auth.database` / `username` | `wallabag` | Database and user created by the subchart |
| `database.external.host` | `""` | External PostgreSQL host (required without the subchart) |
| `database.external.port` | `"5432"` | External PostgreSQL port |
| `database.external.name` / `username` | `wallabag` | External database and user |
| `database.external.password` | `""` | Inline password, stored in `<release>-wallabag-db` |
| `database.external.existingSecret` | `""` | Existing Secret with the database password |
| `database.external.existingSecretPasswordKey` | `password` | Key in the database Secret |
| `redis.enabled` | `false` | Deploy the HelmForge Redis subchart |
| `externalRedis.host` / `port` | `""` / `"6379"` | External Redis endpoint |
| `externalRedis.password` / `existingSecret` | `""` | External Redis password or existing Secret |
| `externalRedis.existingSecretPasswordKey` | `redis-password` | Key in the Redis Secret |

See [docs/external-database.md](docs/external-database.md) for managed
PostgreSQL and [docs/configuration.md](docs/configuration.md) for Redis and
listener details.

### Exposure, probes, and storage

| Key | Default | Description |
|-----|---------|-------------|
| `service.type` / `service.port` | `ClusterIP` / `80` | Service type and port |
| `ingress.enabled` | `false` | Render an Ingress |
| `ingress.ingressClassName` | `traefik` | Ingress class |
| `gatewayAPI.enabled` | `false` | Render Gateway API HTTPRoutes |
| `gatewayAPI.httpRoutes` | `[]` | HTTPRoutes; each requires `parentRefs` |
| `probes.path` | `/api/info` | HTTP path used by every probe |
| `persistence.enabled` | `true` | PVC for `/var/www/wallabag/data` |
| `persistence.size` | `2Gi` | PVC size |
| `persistence.existingClaim` | `""` | Use an existing PVC |
| `backup.enabled` | `false` | Scheduled `pg_dump` upload to S3 |

Backup settings are documented in
[docs/backup-restore.md](docs/backup-restore.md). Every key is listed in
`values.yaml` and validated by `values.schema.json`.

## Examples

- [examples/external-database.yaml](examples/external-database.yaml): managed PostgreSQL with an existing Secret
- [examples/production-with-redis-and-backup.yaml](examples/production-with-redis-and-backup.yaml): Ingress with TLS, Redis, daily backups, and resource limits

## Security

- The upstream image starts as root and drops to `nobody` for PHP-FPM, so
  `runAsNonRoot` and a read-only root filesystem are not supported. The chart
  disables privilege escalation, drops every capability the image does not
  need, applies the `RuntimeDefault` seccomp profile, and does not mount a
  ServiceAccount token.
- Every credential is read from a Secret and accepts an existing Secret.
- Registration is disabled by default. Enable it only when the instance is
  meant to be public.

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Pod stuck in `Init:0/1` | `kubectl logs deploy/<release>-wallabag -c setup`; PostgreSQL is not reachable or the credentials are wrong |
| HTTP 500 on every page | The schema is missing; confirm `setup.enabled=true` and read the setup logs |
| Login rejected after install | Read the password from `<release>-wallabag-admin`; it applies only to the first install |
| Container exits with `Unable to configure the nginx listener` | The image changed its nginx configuration; pin a supported `image.tag` |

## More Information

- [Wallabag documentation](https://doc.wallabag.org)
- [Chart source](https://github.com/helmforgedev/charts/tree/main/charts/wallabag)
- [Chart design](DESIGN.md), [configuration](docs/configuration.md),
  [external database](docs/external-database.md), and
  [backup and restore](docs/backup-restore.md)

### Security Scan: `wallabag`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **87.878784%** |

> Security posture acceptable.

<!-- @AI-METADATA
type: chart-readme
title: Wallabag Helm Chart
description: README for the Wallabag read-it-later Helm chart

keywords: wallabag, read-it-later, bookmarks, articles, postgresql, redis

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/wallabag/values.yaml
path: charts/wallabag/README.md
version: 1.1
date: 2026-10-24
-->
