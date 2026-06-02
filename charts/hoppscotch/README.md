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
  --version 1.1.2
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
  --set ingress.ingressClassName=nginx \
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
- **Proxy URL bootstrap** — optional `PROXY_APP_URL` default for self-hosted deployments
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
Inside the pod, the AIO Caddy server listens on non-root port `8081` via
`HOPP_AIO_ALTERNATE_PORT`; the Kubernetes Service maps external port `80` to
that named container port. Port `8080` remains reserved for the Hoppscotch
backend process inside the AIO image.

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mode` | Chart mode: `dev` or `production` | `dev` |
| `image.tag` | Hoppscotch image tag | `2026.5.0` |
| `namespaceOverride` | Namespace for chart-managed resources. Use with an external database; bundled PostgreSQL remains in the Helm release namespace. | `""` |
| `replicaCount` | Number of replicas | `1` |
| `ingress.enabled` | Enable Ingress | `false` |
| `ingress.host` | Primary hostname (auto-derives all URLs) | `""` |
| `postgresql.enabled` | Enable PostgreSQL subchart (`helmforge/postgresql` `2.0.2`) | `true` |
| `postgresql.initdb.scripts` | Bootstrap Hoppscotch PostgreSQL extensions | `pg_trgm` |
| `postgresqlExtensionsJob.enabled` | Run the pre-upgrade hook that ensures `pg_trgm` exists on bundled PostgreSQL PVCs before Prisma migrations | `true` |
| `postgresqlExtensionsJob.requireExistingResources` | Only render the `pg_trgm` pre-upgrade hook when bundled PostgreSQL resources already exist | `true` |
| `database.external.enabled` | Use external PostgreSQL | `false` |
| `encryption.key` | 32-char encryption key (auto-generated) | `""` |
| `signingKey.existingSecret` | Existing Secret that contains `WEBAPP_SERVER_SIGNING_KEY` | `""` |
| `signingKey.existingSecretKey` | Secret key used for `WEBAPP_SERVER_SIGNING_KEY` | `webapp-server-signing-key` |
| `serviceAccount.automountServiceAccountToken` | Mount the Kubernetes API token into Hoppscotch pods and hook jobs | `false` |
| `auth.providers` | Enabled auth providers | `EMAIL` |
| `mailer.enabled` | Enable SMTP | `false` |
| `proxy.appUrl` | Default proxy URL exposed as `PROXY_APP_URL` | `""` |
| `service.containerPort` | Internal non-root Hoppscotch AIO HTTP port | `8081` |
| `gateway.enabled` | Enable HTTPRoute | `false` |
| `externalSecrets.enabled` | Enable ExternalSecret | `false` |
| `externalSecrets.apiVersion` | ExternalSecret API version | `external-secrets.io/v1` |
| `networkPolicy.enabled` | Enable NetworkPolicy | `false` |
| `podDisruptionBudget.enabled` | Enable PDB | `false` |

## Upgrade Notes

Hoppscotch `2026.5.0` adds OpenAPI 3.1 collection export, configurable proxy URLs through environment/admin settings,
Mongolian language support, security patches, and fixes that prevent secret variable values from leaking to the backend.
Back up the PostgreSQL database and keep `DATA_ENCRYPTION_KEY` stable before upgrading.
The bundled PostgreSQL path now derives `DATABASE_URL` from the PostgreSQL
user password Secret, bootstraps `pg_trgm` on fresh data directories, and runs
a pre-upgrade hook to apply `pg_trgm` to existing bundled PostgreSQL PVCs before
Prisma migrations run.
The chart also persists `WEBAPP_SERVER_SIGNING_KEY` in the chart Secret so
signed web bundles remain valid across pod restarts. When using External
Secrets, include `webapp-server-signing-key` in `externalSecrets.data`, or set
`signingKey.existingSecret` and `signingKey.existingSecretKey` to reference a
separately managed Secret.

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
- [Chart Design](DESIGN.md)

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
