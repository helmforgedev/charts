# Authelia Architecture

## Overview

Authelia is an authentication and authorization server providing single sign-on (SSO), multi-factor authentication (MFA), and OpenID Connect identity provider capabilities. It works as a forward-auth middleware for reverse proxies like Traefik, nginx, Caddy, and Envoy.

## Deployment Model

The chart deploys a single-replica Deployment with `Recreate` strategy. Authelia listens on port **9091** for HTTP and optionally **9959** for Prometheus metrics.

## Configuration

Authelia uses a YAML configuration file (`configuration.yml`) rendered as a Kubernetes Secret. Sensitive values (JWT secret, session secret, storage encryption key, database passwords) are injected via file-based secrets mounted at `/secrets/`.

### Configuration Injection Pattern

```
configuration.yml  →  Secret (mounted at /config/configuration.yml)
Credentials        →  Secret (mounted at /secrets/)
Users database     →  Secret (mounted at /config/users_database.yml)
```

Environment variables with `_FILE` suffix tell Authelia to read secrets from files:

- `AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET_FILE`
- `AUTHELIA_SESSION_SECRET_FILE`
- `AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE`
- `AUTHELIA_STORAGE_POSTGRES_PASSWORD_FILE` (PostgreSQL mode)
- `AUTHELIA_STORAGE_MYSQL_PASSWORD_FILE` (MySQL mode)
- `AUTHELIA_SESSION_REDIS_PASSWORD_FILE` (Redis session mode)

## Storage Backends

| Backend | Config Key | Use Case |
|---------|-----------|----------|
| SQLite | `storage.local` | Single instance, development, small deployments |
| PostgreSQL | `storage.postgres` | Production, HA-ready |
| MySQL/MariaDB | `storage.mysql` | Production alternative |

The chart automatically configures the storage section based on `database.type` and enabled subcharts.

## Session Storage

| Provider | Config Key | Use Case |
|----------|-----------|----------|
| In-memory | (default) | Single instance only |
| Redis | `session.redis` | Required for HA, recommended for production |

When `redis.enabled=true`, the chart automatically injects the Redis connection into the session configuration.

## Authentication Backends

| Backend | Config Key | Use Case |
|---------|-----------|----------|
| File | `authentication_backend.file` | Small deployments, testing |
| LDAP | `authentication_backend.ldap` | Enterprise, Active Directory |

The file backend uses a `users_database.yml` mounted from a Secret. Users can be defined inline in `usersDatabase.users` or provided via `usersDatabase.existingSecret`.

## Health Checks

- **Startup/Liveness/Readiness**: `GET /api/health` on port 9091
- **Metrics**: `GET /metrics` on port 9959 (when telemetry is enabled)

## Forward Auth Integration

Authelia provides several authorization endpoints:

| Endpoint | Proxy |
|----------|-------|
| `/api/authz/forward-auth` | Traefik ForwardAuth |
| `/api/authz/auth-request` | nginx auth_request |
| `/api/authz/ext-authz` | Envoy ExtAuthz |

Configure your reverse proxy to forward authentication requests to `http://<release>-authelia.<namespace>.svc.cluster.local/api/authz/<method>`.

## Backup Strategy

| Storage | Method | Tool |
|---------|--------|------|
| SQLite | tar archive of /data | busybox |
| PostgreSQL | pg_dump | postgres image |
| MySQL | mysqldump | mysql image |

All backup modes upload to S3-compatible storage via `minio/mc`.

<!-- @AI-METADATA
@description: Architecture overview for the Authelia Helm chart
@type: chart-docs
@path: charts/authelia/docs/architecture.md
@date: 2026-03-23
@relations:
  - charts/authelia/README.md
  - charts/authelia/values.yaml
-->
