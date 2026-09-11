# Ryot Helm Chart

Deploy [Ryot](https://github.com/IgnisDa/ryot) for private personal tracking with the official
`ghcr.io/ignisda/ryot:v10.5.0` image and HelmForge PostgreSQL.

## Production contract

- One application replica with Recreate upgrades and one active native scheduler.
- Protected native administrator creation before the public process starts; existing users are preserved.
- Closed registration, local password authentication, retained administrator override and initial-password Secrets.
- Non-root UID 1001, read-only root filesystem, dropped capabilities and no Kubernetes API token.
- Native frontend, Rust backend and Caddy retained together; dedicated temporary directories preserve frontend assets.
- HelmForge PostgreSQL with restricted credentials, required extensions, persistent data and network isolation.
- External PostgreSQL components with Secret-backed passwords and verified TLS by default.
- Ingress, Gateway API, dual-stack Service, External Secrets Operator and placement controls.
- Native session and private-collection persistence checks, plus logical database recovery verification.

**This version supports local authentication only. OIDC and S3 are deliberately unavailable in the chart.** The native
OIDC login accepts a stored subject without proving a provider exchange; this was reproduced only with an owned
disposable account. The chart refuses to start with OIDC-linked database accounts. Source inspection also found S3
signing and deletion operations without user authorization or ownership checks. Merely putting credentials in a Secret
does not repair those upstream behaviors. See [security and integrations](docs/security.md).

## Installation

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install ryot helmforge/ryot -f values.yaml
kubectl port-forward svc/ryot-ryot 8000:8000
```

The initial account is `admin`; customize `bootstrap.username` before installation. Helm NOTES identifies the initial
password Secret. Prefer `bootstrap.existingSecret` and `auth.existingSecret` for GitOps. Updating an initial-password
Secret never resets an existing account. The administrator override must contain at least 32 characters and remain
stable through upgrades and recovery.

For remote use, set `server.publicUrl` to the exact HTTPS origin, configure Ingress or Gateway routing and allow the
controller through `networkPolicy.ingressFrom`. Default ingress permits same-namespace pods only. The proxy health
endpoint also probes the native backend. Resource limits must accommodate both the frontend and backend.

## Database choices

Bundled PostgreSQL is enabled by default. Its native first-boot scripts prepare `uuid-ossp` and `pg_trgm` as the
database administrator; the Ryot process uses the separate application user. Keep these scripts and the writable
PostgreSQL temporary/socket mounts when overriding dependency values. Scripts do not rerun on an existing database
volume.

For external PostgreSQL, disable `postgresql.enabled` and set `database.host`, `database.name`, `database.username` and
`database.passwordSecret`. A DBA must prepare both extensions and schema privileges before deployment. The chart builds
the URI in a private memory volume with correctly encoded credentials. External connections default to `verify-full`;
use `database.caSecret` for a private CA and permit the database destination through NetworkPolicy. PostgreSQL is the
only supported database engine.

The read-only admission check waits for an authenticated database connection, rejects OIDC-linked accounts and decides
whether first-administrator setup is needed. Native migrations fail closed before readiness. Disabling bootstrap does
not disable database admission or the nonempty administrator-override requirement.

## Durability and availability

User accounts, native sessions and tracking records live in PostgreSQL. Application temporary files, import staging and
logs are ephemeral; archive relevant logs through the platform. A single scheduler avoids duplicate native background
processing, so horizontal autoscaling and single-replica disruption budgets are not exposed as availability features.
Recreate upgrades include downtime.

Back up PostgreSQL and retain authentication Secrets before upgrades. Native migrations are not reversed by Helm
rollback. The recovery profile quiesces the application, creates a native custom-format dump, restores into a separate
empty database and verifies the original session and private collection before cleanup. It does not claim multi-node
database failover. See [database operations and recovery](docs/recovery.md).

## Integrations and monitoring

Default egress allows DNS and the selected bundled database. Explicitly allow external databases and trusted provider
APIs using `networkPolicy.extraEgress` or `networkPolicy.webEgress`. Provider credentials may use Secret references in
`extraEnv`; managed identity, database and unsafe storage settings cannot be overridden there.

No native Prometheus endpoint is claimed for this release. Monitor application health, workload resources, native logs
and the PostgreSQL dependency with your platform tooling. PostgreSQL exposes its own documented exporter and
ServiceMonitor options. SMTP delivery is not part of this chart's verified integration contract; its native test can
return success despite a failed send.

## Security Scan: `ryot`

| Framework | Score      |
| --------- | ---------- |
| Overall   | **99.39%** |
| MITRE     | **98.82%** |
| NSA       | **99.00%** |
| SOC2      | **96.00%** |

Kubescape 4.0.13, default manifests including PostgreSQL, 2026-09-10. C-0012 flags the bootstrap script's
password-handling code inside a ConfigMap; actual credential values come from Secrets and are not embedded in that
script. The finding remains visible without suppression. This configuration scan does not establish upstream application
security or image vulnerability status; the OIDC and S3 restrictions above remain mandatory regardless of this score.

## Gateway API contract

Use `gatewayAPI.enabled` and `gatewayAPI.httpRoutes[]`. Set each route's `parentRefs` to a shared Gateway that allows
this namespace, and configure its HTTPS listener and public hostname. Routes accept labels, annotations and rules
with matches, filters and optional backend references; omitted backends target this chart's application Service.
Ingress and HTTPRoute resources can coexist. Verify controller conditions and public traffic before production use.
See the [Gateway API documentation](https://gateway-api.sigs.k8s.io/).
