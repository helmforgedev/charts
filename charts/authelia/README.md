# Authelia Helm Chart

Deploy [Authelia](https://www.authelia.com) on Kubernetes — an authentication and authorization server with SSO, MFA (TOTP, WebAuthn, Duo), and OpenID Connect provider capabilities.

## Features

- **Forward auth** for Traefik, nginx, Caddy, and Envoy
- **Multi-factor authentication** — TOTP, WebAuthn/FIDO2, Duo
- **OpenID Connect** certified identity provider
- **File or LDAP** authentication backends
- **SQLite, PostgreSQL, or MySQL** storage backends
- **Redis** session storage for stateless deployments
- **Access control rules** with domain, user, group, and network policies
- **Brute force protection** with configurable regulation
- **Prometheus metrics** with optional ServiceMonitor
- **S3 backup** — SQLite tar, pg_dump, or mysqldump with S3 upload
- **Ingress support** with TLS via cert-manager
- **Gateway API** — HTTPRoute via `gateway.enabled=true` (GR-060)
- **External Secrets Operator** — opt-in ExternalSecret via `externalSecrets.enabled=true` (GR-061)
- **Dual-stack** — `service.ipFamilyPolicy` / `service.ipFamilies` (GR-058)

## Architecture

The chart runs the official Authelia image behind a named-port Service and
optional Ingress or HTTPRoute. A rendered configuration Secret and separate
credential/user Secrets are mounted read-only. SQLite uses the application PVC;
production profiles can select bundled or external PostgreSQL/MySQL and optional
Redis session storage. Native health and metrics listeners follow
`containerPorts`, while the ingress-only NetworkPolicy limits reachable Pod
ports without blocking external identity, mail or storage dependencies.

## Installation

**HTTPS repository:**

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install authelia helmforge/authelia -f values.yaml
```

**OCI registry:**

```bash
helm install authelia oci://ghcr.io/helmforgedev/helm/authelia -f values.yaml
```

## Quick Start (SQLite)

`jwtSecret`, `sessionSecret`, and `storageEncryptionKey` are **auto-generated** on first `helm install` and persisted across upgrades via cluster lookup.
No manual configuration required for direct installs.

> **GitOps users (Argo CD, Flux):** set `secrets.jwtSecret`, `secrets.sessionSecret`, and `secrets.storageEncryptionKey` explicitly.
> Client-side rendering cannot perform cluster lookups, so leaving these empty will rotate credentials on every sync.

A disabled placeholder `admin` account is shipped because Authelia requires a non-empty file users database when the file backend is enabled.
Enable it only after setting a strong password hash. Generate one with:

```bash
docker run authelia/authelia:4.39.28 authelia crypto hash generate argon2
```

```yaml
# values.yaml — minimal production example
config:
  session:
    cookies:
      - domain: example.com
        authelia_url: "https://auth.example.com"
  access_control:
    default_policy: one_factor

usersDatabase:
  users:
    admin:
      disabled: false
      displayname: "Admin"
      email: "admin@example.com"
      password: "$argon2id$v=19$m=65536,t=3,p=4$..."  # replace with your hash
      groups:
        - admins
```

Access via `kubectl port-forward svc/<release>-authelia 9091:80`.

## PostgreSQL + Redis Mode

```yaml
database:
  type: postgres

postgresql:
  enabled: true
  auth:
    password: "strong-password"

redis:
  enabled: true
  auth:
    password: "strong-redis-password"
```

## MySQL Mode

```yaml
database:
  type: mysql

mysql:
  enabled: true
  auth:
    password: "strong-password"
```

## External Database

```yaml
database:
  type: postgres
  external:
    host: postgres.example.com
    name: authelia
    username: authelia
    existingSecret: authelia-db-credentials

postgresql:
  enabled: false
```

## Key Values

| Key | Default | Description |
|-----|---------|-------------|
| `config` | (see values.yaml) | Full Authelia configuration rendered as YAML |
| `containerPorts.http` | `9091` | Native Authelia HTTP listener |
| `containerPorts.metrics` | `9959` | Native Prometheus listener |
| `secrets.jwtSecret` | `""` | JWT secret — **auto-generated** on first install if empty |
| `secrets.sessionSecret` | `""` | Session secret — **auto-generated** on first install if empty |
| `secrets.storageEncryptionKey` | `""` | Storage key — **auto-generated** on first install if empty |
| `secrets.existingSecret` | `""` | Use existing secret for credentials |
| `database.type` | `sqlite` | Storage backend: sqlite, postgres, mysql |
| `usersDatabase.enabled` | `true` | Mount file-based users database |
| `usersDatabase.users` | disabled admin placeholder | Inline user definitions. Enable only after setting a strong password hash |
| `persistence.enabled` | `true` | Enable PVC for /data |
| `persistence.size` | `1Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `gateway.enabled` | `false` | Enable Gateway API HTTPRoute (requires Gateway API CRDs) |
| `externalSecrets.enabled` | `false` | Render ExternalSecret for credentials (requires ESO) |
| `service.ipFamilyPolicy` | `~` | Dual-stack policy: SingleStack, PreferDualStack, RequireDualStack |
| `service.ipFamilies` | `[]` | Dual-stack IP families: IPv4, IPv6 |
| `networkPolicy.enabled` | `true` | Restrict ingress to declared listeners |
| `serviceAccount.automountServiceAccountToken` | `false` | Keep Kubernetes API credentials out of the Pod |
| `metrics.enabled` | `false` | Enable metrics service |
| `backup.enabled` | `false` | Enable S3 backups |
| `podSecurityContext.fsGroup` | `1000` | Run with a non-root writable group for persistent data |
| `securityContext.runAsNonRoot` | `true` | Run Authelia without root privileges by default |
| `postgresql.enabled` | `false` | Deploy PostgreSQL subchart |
| `mysql.enabled` | `false` | Deploy MySQL subchart |
| `redis.enabled` | `false` | Deploy Redis subchart |

## Bundled Dependency Versions

The chart uses HelmForge-maintained subcharts for optional stateful services:

| Dependency | Version | Usage |
|------------|---------|-------|
| PostgreSQL | `2.1.1` | Production storage backend |
| MySQL | `2.1.1` | Production storage backend alternative |
| Redis | `3.1.0` | Session storage for distributed/HA deployments |

`containerPorts.http` and `containerPorts.metrics` are the listener source of
truth. The chart generates `server.address` and `telemetry.metrics.address` from
them, so the process, probes and named Service targets remain aligned.

For upgrades from releases before 1.5.18, retained `config.server.address` and
`config.telemetry.metrics.address` values remain supported and take precedence
over the new default ports. Migrate those addresses to `containerPorts` when
editing the configuration.

Do not upgrade from chart 1.5.17 with `--reuse-values` alone. It can omit the
newer `networkPolicy` parent map and make template rendering fail at
`.Values.networkPolicy.enabled`. With Helm 3.14 or later, use
`helm upgrade --reset-then-reuse-values` and review the rendered diff before
applying the upgrade. With Helm 3.13 or earlier, export the release overrides
with `helm get values RELEASE -o yaml > retained-values.yaml`, then pass them
to `helm upgrade --reset-values -f retained-values.yaml RELEASE CHART`.

## Security

Use stable existing Secrets or External Secrets for the JWT, session and storage
encryption keys. Treat those values and the selected database as one recovery
set; losing the storage encryption key permanently makes enrolled TOTP and
WebAuthn data unreadable. Terminate TLS at a trusted proxy, configure trusted
headers explicitly and restrict access to the rendered configuration Secret.
The default read-only root filesystem uses a bounded `/tmp` volume, disables API
token mounting and restricts ingress to the HTTP and optional metrics listeners.
Set explicit `networkPolicy.ingressFrom` peers when the platform owns trusted
proxy namespaces.

## Troubleshooting

- If the Pod does not become ready, inspect `/api/health`, application logs and
  database or Redis endpoints before restarting it.
- If a custom port fails, confirm `containerPorts.http` or
  `containerPorts.metrics`; legacy listener addresses under `config` take
  precedence when retained from an older release.
- If login redirects or cookies fail, verify the public Authelia URL, cookie
  domain, TLS scheme and reverse-proxy forwarded headers.
- If MFA data cannot be decrypted, restore the matching database and original
  storage encryption key. Generating a replacement key does not recover data.

## Forward Auth Configuration

### Traefik

Add a middleware pointing to Authelia's forward-auth endpoint:

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: authelia
spec:
  forwardAuth:
    address: http://<release>-authelia.<namespace>.svc.cluster.local/api/authz/forward-auth
    trustForwardHeader: true
    authResponseHeaders:
      - Remote-User
      - Remote-Groups
      - Remote-Email
      - Remote-Name
```

### nginx

Use the `auth_request` directive:

```nginx
auth_request /authelia;
auth_request_set $user $upstream_http_remote_user;
```

## Upgrading to 4.39.28

The 4.39.23-4.39.28 patches fix OIDC client authentication, resource grants,
client-credentials subjects, JARM responses, storage queries and SMTP IPv6
addresses. Remove the obsolete `website` configuration attribute from custom
configuration. Review all intervening releases:
[4.39.23](https://github.com/authelia/authelia/releases/tag/v4.39.23),
[4.39.24](https://github.com/authelia/authelia/releases/tag/v4.39.24),
[4.39.25](https://github.com/authelia/authelia/releases/tag/v4.39.25),
[4.39.26](https://github.com/authelia/authelia/releases/tag/v4.39.26),
[4.39.27](https://github.com/authelia/authelia/releases/tag/v4.39.27), and
[4.39.28](https://github.com/authelia/authelia/releases/tag/v4.39.28).

The bundled dependency baseline is PostgreSQL 2.1.1, MySQL 2.1.1 and Redis
3.1.0. Their documented storage and authentication contracts remain unchanged.

Authelia 4.39.21 changes storage encryption to use HKDF and authenticated
additional data; 4.39.22 fixes the access-token JWT session migration. Back up
the database and retain the storage encryption key before upgrading. Allow
startup migrations to complete before serving traffic. Restore the matching
database backup and key if a rollback requires the previous storage format.

The chart preserves generated credentials through Helm cluster lookup. Use an
existing Secret for GitOps or offline rendering, where lookup cannot retrieve
the installed key. Do not rotate the storage key as part of an image update.
After rollout, run `authelia storage encryption check --config /config/configuration.yml`
inside the Authelia container and verify application health and MFA enrollment.

Release notes: [4.39.21](https://github.com/authelia/authelia/releases/tag/v4.39.21),
[4.39.22](https://github.com/authelia/authelia/releases/tag/v4.39.22).

## More Information

- [Architecture](docs/architecture.md) — deployment model, configuration injection, forward auth setup
- [Authelia Documentation](https://www.authelia.com/configuration/prologue/introduction/)
- [Source Code](https://github.com/helmforgedev/charts/tree/main/charts/authelia)

### Security Scan: `authelia`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **87.88%** |

Kubescape 4.0.14 scan of rendered Kubernetes resources on 2026-09-15; application authentication and storage
behavior require separate runtime validation.

<!-- @AI-METADATA
@description: README for the Authelia Helm chart
@type: chart-readme
@path: charts/authelia/README.md
@date: 2026-03-23
@relations:
  - charts/authelia/values.yaml
  - charts/authelia/docs/architecture.md
-->
