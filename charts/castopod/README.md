# Castopod Helm Chart

Deploy [Castopod](https://castopod.org), the open-source podcast hosting
platform with RSS feeds, a web player, analytics, and ActivityPub federation,
on Kubernetes with the official
[castopod/castopod](https://hub.docker.com/r/castopod/castopod) image.

## Features

- **Ready on first start**: a setup init container applies migrations and
  creates the superadmin from a Secret; no open `/cp-install` wizard
- **Hardened pod**: non-root `www-data`, no privilege escalation, every
  capability dropped except `NET_BIND_SERVICE`, `RuntimeDefault` seccomp
- **Scheduler sidecar**: scheduled publishing, WebSub, and federation tasks
  run every minute
- **MariaDB backend**: HelmForge MariaDB subchart or an external server on any port
- **Optional Redis cache**: authenticated HelmForge Redis subchart
- **Persistent media**: uploaded audio and images survive pod restarts
- **Stable secrets**: analytics salt and superadmin password survive `helm upgrade`
- **Configurable listener**: `castopod.port` changes the real FrankenPHP port
- **Exposure**: Ingress or Gateway API HTTPRoutes
- **S3 backups**: scheduled archives of the data volume

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install castopod helmforge/castopod \
  --set castopod.baseURL=https://podcast.example.com
```

**OCI registry:**

```bash
helm install castopod oci://ghcr.io/helmforgedev/helm/castopod \
  --set castopod.baseURL=https://podcast.example.com
```

## Quick Start

Without a base URL, Ingress, or HTTPRoute, the chart uses
`http://localhost:8080` and disables HTTPS redirection, which suits a local
check:

```bash
helm install castopod helmforge/castopod
kubectl rollout status deploy/castopod-castopod --timeout=300s
kubectl get secret castopod-castopod-admin -o jsonpath='{.data.admin-password}' | base64 -d; echo
kubectl port-forward svc/castopod-castopod 8080:80
```

Open `http://localhost:8080/cp-auth/login` and log in with `admin@example.com`
and the password above. Resource names follow `<release>-castopod`.

## Architecture

The pod runs a `setup` init container, the `castopod` container (FrankenPHP),
and a `scheduler` sidecar (supercronic), all from the same image. The setup
container waits for MariaDB, runs the upstream bootstrap (`.env`, migrations,
cache), and creates the superadmin once. See [DESIGN.md](DESIGN.md) for the
design, including why the upstream s6-overlay supervisor is not used.

## Configuration

### Application

| Key | Default | Description |
|-----|---------|-------------|
| `castopod.baseURL` | `""` | Public URL; falls back to the first Ingress host, then HTTPRoute hostname, then `http://localhost:8080` |
| `castopod.mediaBaseURL` | `""` | Media URL, for a CDN; defaults to the base URL |
| `castopod.port` | `8080` | FrankenPHP listener (`CADDY_HTTP_PORT`), 1024-65535 |
| `castopod.adminGateway` | `cp-admin` | Admin area path |
| `castopod.authGateway` | `cp-auth` | Authentication path |
| `castopod.extraEnv` | `[]` | Extra env vars; `CP_*` settings (SMTP, S3 media, 2FA) go into `.env` |
| `castopod.admin.create` | `true` | Create the superadmin when none exists |
| `castopod.admin.username` | `admin` | Superadmin username |
| `castopod.admin.email` | `admin@example.com` | Superadmin email, used to log in |
| `castopod.admin.password` | `""` | Superadmin password (8+ characters); generated once when empty |
| `castopod.admin.existingSecret` | `""` | Existing Secret with the superadmin password |
| `castopod.admin.existingSecretPasswordKey` | `admin-password` | Key in that Secret |
| `analytics.salt` / `existingSecret` | `""` | Analytics salt; generated once and kept on upgrade |
| `setup.databaseWaitTimeoutSeconds` | `300` | Seconds the setup container waits for MariaDB |
| `scheduler.enabled` | `true` | Run the task scheduler sidecar |

### Database and Redis

| Key | Default | Description |
|-----|---------|-------------|
| `mariadb.enabled` | `true` | Deploy the HelmForge MariaDB subchart |
| `mariadb.auth.database` / `username` | `castopod` | Database and user created by the subchart |
| `database.external.host` | `""` | External MariaDB host (required without the subchart) |
| `database.external.port` | `"3306"` | External MariaDB port |
| `database.external.name` / `username` | `castopod` | External database and user |
| `database.external.password` | `""` | Inline password, stored in `<release>-castopod-db` |
| `database.external.existingSecret` | `""` | Existing Secret with the database password |
| `database.external.existingSecretPasswordKey` | `password` | Key in that Secret |
| `redis.enabled` | `false` | Deploy the Redis subchart and use it as the cache handler |
| `redis.auth.enabled` | `true` | Must stay `true`: Castopod requires a Redis password |

### Exposure, probes, and storage

| Key | Default | Description |
|-----|---------|-------------|
| `service.type` / `service.port` | `ClusterIP` / `80` | Service type and port |
| `ingress.enabled` | `false` | Render an Ingress |
| `ingress.ingressClassName` | `traefik` | Ingress class |
| `gatewayAPI.enabled` | `false` | Render Gateway API HTTPRoutes |
| `gatewayAPI.httpRoutes` | `[]` | HTTPRoutes; each requires `parentRefs` |
| `probes.path` | `/healthcheck` | HTTP path used by every probe |
| `persistence.enabled` | `true` | PVC for writable files and uploaded media |
| `persistence.size` | `10Gi` | PVC size |
| `persistence.existingClaim` | `""` | Use an existing PVC |
| `backup.enabled` | `false` | Scheduled archive of the data volume to S3 |

Every key is documented in `values.yaml` and validated by
`values.schema.json`. See [docs/configuration.md](docs/configuration.md) for
external databases, Redis, SMTP, and backups.

## Examples

- [examples/production.yaml](examples/production.yaml): HTTPS Ingress, existing
  Secrets, Redis, a 50Gi media volume, resources, and daily backups

## Security

- The pod runs as `www-data` (uid 33) without privilege escalation, with only
  `NET_BIND_SERVICE` kept (the FrankenPHP binary needs it in the bounding set
  to start), `RuntimeDefault` seccomp, and no ServiceAccount token.
- The root filesystem stays writable because Caddy and the bootstrap write to
  the image tree.
- Credentials come from Secrets and accept existing Secrets. The rendered
  `.env` is kept in a memory-backed volume, and the setup logs hide it.
- Keep `castopod.admin.create=true` unless you complete `/cp-install` before
  exposing the instance; the first visitor of the wizard becomes the owner.

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Pod stuck in `Init:0/1` | `kubectl logs deploy/<release>-castopod -c setup`; MariaDB is unreachable or the credentials are wrong |
| Redirect loop or HTTPS errors behind a proxy | Set `castopod.baseURL` to the public `https://` URL and forward `X-Forwarded-Proto` |
| Login rejected | Log in with the email, not the username; read the password from `<release>-castopod-admin` |
| Scheduled episodes never publish | Confirm `scheduler.enabled=true` and read `-c scheduler` logs |

## More Information

- [Castopod documentation](https://docs.castopod.org)
- [Castopod source](https://code.castopod.org/adaures/castopod)
- [Chart source](https://github.com/helmforgedev/charts/tree/main/charts/castopod)
- [Chart design](DESIGN.md) and [configuration](docs/configuration.md)

### Security Scan: `castopod`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **87.878784%** |

> Security posture acceptable.

<!-- @AI-METADATA
type: chart-readme
title: Castopod Helm Chart
description: README for the Castopod podcast hosting Helm chart

keywords: castopod, podcast, hosting, fediverse, mariadb, redis

purpose: Chart installation, configuration, and usage documentation
scope: Chart

relations:
  - charts/castopod/values.yaml
  - charts/castopod/Chart.yaml
path: charts/castopod/README.md
version: 1.1
date: 2026-10-24
-->
