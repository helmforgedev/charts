# Hoppscotch

Hoppscotch Community Edition for Kubernetes — open-source API development platform with REST, GraphQL, and WebSocket support.

## Installation

### Helm HTTPS Repository

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install hoppscotch helmforge/hoppscotch
```

### OCI Registry

```bash
helm install hoppscotch oci://ghcr.io/helmforgedev/helm/hoppscotch \
  --version 0.1.0
```

## Quick Start

### Minimal (dev mode)

```bash
helm install hoppscotch helmforge/hoppscotch \
  --set ingress.enabled=true \
  --set ingress.host=hoppscotch.local
```

### Production

```bash
helm install hoppscotch helmforge/hoppscotch \
  --set mode=production \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.host=hoppscotch.example.com \
  --set "ingress.tls[0].secretName=hoppscotch-tls" \
  --set "ingress.tls[0].hosts[0]=hoppscotch.example.com" \
  --set "ingress.annotations.cert-manager\\.io/cluster-issuer=letsencrypt-prod"
```

## Features

- **All-in-One image** — single Deployment, three services (frontend, backend, admin) via subpath routing
- **Automatic URL derivation** — all VITE_* URLs derived from `ingress.host`
- **Prisma migrations** — automatic via init container on every deploy
- **OAuth providers** — GitHub, Google, Microsoft, EMAIL (magic links)
- **SMTP support** — URL mode or field-by-field
- **ExternalSecrets Operator** — native support
- **Gateway API** — HTTPRoute support
- **Dual-stack networking** — `ipFamilyPolicy` and `ipFamilies` on Service
- **Production hardening** — non-root, capability drop, PDB, NetworkPolicy
- **Monitoring** — ServiceMonitor for Prometheus

## Architecture

Hoppscotch AIO uses subpath-based routing (`ENABLE_SUBPATH_BASED_ACCESS=true`):

| Path | Service |
|------|---------|
| `/` | Frontend (main app) |
| `/backend` | REST API + GraphQL + WebSocket |
| `/admin` | Admin Dashboard |

All traffic goes through a single Ingress/Service on port 80.

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mode` | Chart mode: `dev` or `production` | `dev` |
| `image.tag` | Hoppscotch image tag | `2026.3.1` |
| `replicaCount` | Number of replicas | `1` |
| `ingress.enabled` | Enable Ingress | `false` |
| `ingress.host` | Primary hostname (auto-derives all URLs) | `""` |
| `postgresql.enabled` | Enable PostgreSQL subchart | `true` |
| `database.external.enabled` | Use external PostgreSQL | `false` |
| `encryption.key` | 32-char encryption key (auto-generated) | `""` |
| `auth.providers` | Enabled auth providers | `EMAIL` |
| `mailer.enabled` | Enable SMTP | `false` |
| `gatewayAPI.enabled` | Enable HTTPRoute | `false` |
| `externalSecrets.enabled` | Enable ExternalSecret | `false` |
| `networkPolicy.enabled` | Enable NetworkPolicy | `false` |
| `podDisruptionBudget.enabled` | Enable PDB | `false` |

## Examples

- [Minimal dev](examples/minimal.yaml)
- [Production with TLS](examples/production.yaml)
- [External database](examples/external-db.yaml)
- [Full enterprise](examples/full-production.yaml)

## Feature Guides

- [Database](docs/database.md)
- [Authentication](docs/authentication.md)
- [SMTP](docs/smtp.md)
- [Production Hardening](docs/production.md)

## Connecting

After install, port-forward to test:

```bash
kubectl port-forward svc/hoppscotch 8080:80 -n <namespace>
# Open http://localhost:8080
```

First-time setup: the **first user to log in** via `/admin` becomes the administrator.

## Non-Goals

This chart does not:

- Deploy the three-container split architecture (use the AIO image instead)
- Manage OAuth provider registration (do this in the provider's developer console)
- Provide built-in backup for PostgreSQL (use the HelmForge PostgreSQL chart with backup enabled)

## License

Apache-2.0
