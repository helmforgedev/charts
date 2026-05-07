# Discount Bandit Chart Design

## Purpose

This chart packages Discount Bandit for Kubernetes while exposing the operational choices that matter in production:
database ownership, public routing, outbound crawler access, secrets, storage, and pod hardening.

## Application Model

Discount Bandit is a Laravel application running on FrankenPHP. The upstream container starts Supervisor, which runs:

- FrankenPHP/Octane for the web UI
- Laravel scheduler for recurring crawls and maintenance
- Laravel queue worker for background jobs
- Chromium/Xvfb for stores that require browser-based crawling

The application stores data in SQLite by default upstream, but it also supports MySQL/MariaDB through Laravel database
environment variables. For Kubernetes production, this chart makes MySQL the primary path.

## Architecture: Primary MySQL

```text
Users
  |
  v
Gateway API / Ingress
  |
  v
Service discount-bandit
  |
  v
Deployment discount-bandit
  |-- FrankenPHP web UI
  |-- Laravel scheduler
  |-- Laravel queue worker
  |-- Chromium crawler runtime
  |
  v
Service <release>-mysql
  |
  v
StatefulSet mysql
  |
  v
PVC MySQL data
```

Use this for most installations. The MySQL subchart owns database lifecycle, credentials, persistence, and future production
controls from the HelmForge MySQL chart.

## Architecture: External MySQL

```text
Users -> Gateway/Ingress -> Discount Bandit Deployment
                                  |
                                  v
                       External MySQL or MariaDB
                                  |
                                  v
                    Secret or ExternalSecret with password
```

Use this when a platform team already operates MySQL/MariaDB. This mode disables the MySQL subchart and requires an external
database host plus password Secret.

## Architecture: SQLite Dev Mode

```text
Users -> Port-forward/Ingress -> Discount Bandit Deployment
                                  |
                                  v
                         PVC /app/database/sqlite
```

SQLite is kept for development and small personal installs. It must remain single replica because SQLite is single-writer and
the PVC normally uses `ReadWriteOnce`.

## Routing

The chart supports two public HTTP options:

- Ingress for classic ingress controllers.
- Gateway API `HTTPRoute` for clusters using the Kubernetes Gateway API.

Gateway API is appropriate here because Discount Bandit is an HTTP web application. The chart does not create Gateway objects;
it attaches to a platform-owned Gateway through `gatewayAPI.parentRefs`.

## Secrets

The chart manages these sensitive values:

- `APP_KEY`
- external database password
- optional `EXCHANGE_RATE_API_KEY`

Native Kubernetes Secrets are supported for simple installs. External Secrets Operator v1 is supported for production clusters
that source secrets from Vault, cloud secret managers, or other external stores.

## Supervisor Runtime

The upstream image generates Supervisor configuration from `docker/base_supervisord.conf`. That upstream file enables an
unauthenticated loopback `inet_http_server`, which creates a critical log entry even though it is not exposed through the
Service. This chart mounts a sanitized base config at the same path by default:

```text
ConfigMap discount-bandit-supervisor
  |
  v
/app/docker/base_supervisord.conf
  |
  v
php artisan discount:fill-supervisor-workers
  |
  v
/etc/supervisor/conf.d/supervisord.conf
```

The generated runtime config still keeps the web, scheduler, and queue programs, but avoids the unauthenticated Supervisor
HTTP endpoint.

## Networking

Discount Bandit has broader egress needs than a typical internal web app:

- DNS for name resolution
- HTTPS/HTTP egress to product stores for crawling
- HTTPS egress to notification providers and exchange-rate API
- MySQL egress to the same namespace or an external database

`networkPolicy.enabled=false` by default so development installs work without tuning. Production examples enable NetworkPolicy
and document the crawler egress tradeoff.

## Storage

The chart separates storage concerns:

- MySQL data is owned by the MySQL subchart.
- SQLite data uses `persistence.database` only in SQLite mode and is mounted at `/app/database/sqlite` so upstream
  migrations and seeders under `/app/database` remain visible.
- Application logs use `persistence.logs`, defaulting to `emptyDir` because Kubernetes-native log collection should read
  container stdout/stderr first.

## Security

Defaults avoid mounting the Kubernetes API token:

```yaml
serviceAccount:
  automountServiceAccountToken: false
```

The upstream image currently runs Supervisor and worker processes in a way that is not assumed to be non-root safe. For that
reason the chart exposes `podSecurityContext` and `securityContext` but does not force a restrictive default that could break
the application before K3D validation.

## Production Checklist

- Use `mysql.enabled=true` or `database.mode=external`.
- Set `discountBandit.appUrl` and `discountBandit.assetUrl`.
- Store `APP_KEY`, database password, and exchange-rate key in Secrets or External Secrets.
- Enable Gateway API or Ingress with TLS.
- Set resource requests and memory limits.
- Validate crawler and notification egress before enabling restrictive NetworkPolicy.
- Review pod logs after adding real product URLs because store-specific crawling may depend on Chromium behavior.
