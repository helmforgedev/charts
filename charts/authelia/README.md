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

`jwtSecret`, `sessionSecret`, and `storageEncryptionKey` are **auto-generated** on first install and persisted across upgrades — no manual configuration required.

A placeholder `admin` user (password: `authelia`) is shipped by default. **Change this before exposing Authelia publicly.**

Generate a new password hash with:
```bash
docker run authelia/authelia:latest authelia crypto hash generate argon2
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
| `secrets.jwtSecret` | `""` | JWT secret — **auto-generated** on first install if empty |
| `secrets.sessionSecret` | `""` | Session secret — **auto-generated** on first install if empty |
| `secrets.storageEncryptionKey` | `""` | Storage key — **auto-generated** on first install if empty |
| `secrets.existingSecret` | `""` | Use existing secret for credentials |
| `database.type` | `sqlite` | Storage backend: sqlite, postgres, mysql |
| `usersDatabase.enabled` | `true` | Mount file-based users database |
| `usersDatabase.users` | admin/authelia placeholder | Inline user definitions — **change in production** |
| `persistence.enabled` | `true` | Enable PVC for /data |
| `persistence.size` | `1Gi` | PVC size |
| `ingress.enabled` | `false` | Enable ingress |
| `gateway.enabled` | `false` | Enable Gateway API HTTPRoute (requires Gateway API CRDs) |
| `externalSecrets.enabled` | `false` | Render ExternalSecret for credentials (requires ESO) |
| `service.ipFamilyPolicy` | `~` | Dual-stack policy: SingleStack, PreferDualStack, RequireDualStack |
| `service.ipFamilies` | `[]` | Dual-stack IP families: IPv4, IPv6 |
| `metrics.enabled` | `false` | Enable metrics service |
| `backup.enabled` | `false` | Enable S3 backups |
| `postgresql.enabled` | `false` | Deploy PostgreSQL subchart |
| `mysql.enabled` | `false` | Deploy MySQL subchart |
| `redis.enabled` | `false` | Deploy Redis subchart |

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

```
auth_request /authelia;
auth_request_set $user $upstream_http_remote_user;
```

## More Information

- [Architecture](docs/architecture.md) — deployment model, configuration injection, forward auth setup
- [Authelia Documentation](https://www.authelia.com/configuration/prologue/introduction/)
- [Source Code](https://github.com/helmforgedev/charts/tree/main/charts/authelia)

<!-- @AI-METADATA
@description: README for the Authelia Helm chart
@type: chart-readme
@path: charts/authelia/README.md
@date: 2026-03-23
@relations:
  - charts/authelia/values.yaml
  - charts/authelia/docs/architecture.md
-->
