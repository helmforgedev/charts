# ChiefOnboarding Database Guide

## Default Database

By default, the chart deploys the HelmForge PostgreSQL subchart:

```yaml
postgresql:
  enabled: true
  architecture: standalone
  auth:
    database: chiefonboarding
    username: chiefonboarding
```

This mode is appropriate for local validation and simple installations.

## External Database

For managed PostgreSQL, disable the subchart and provide the external endpoint:

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgres.example.com
    port: "5432"
    name: chiefonboarding
    username: chiefonboarding
    existingSecret: chiefonboarding-db
    existingSecretPasswordKey: password
```

The existing Secret must contain the configured password key.

## Inline Passwords

Inline external database passwords are supported for CI and disposable test
environments:

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgresql
    name: chiefonboarding
    username: chiefonboarding
    password: "change-me"
```

Do not use inline passwords for production values files.

## Connection Construction

The chart builds:

```text
postgres://<username>:$(DATABASE_PASSWORD)@<host>:<port>/<database>
```

`DATABASE_PASSWORD` is injected from a Kubernetes Secret. This keeps the
rendered deployment from containing the literal password.

## Operational Guidance

Production database recommendations:

- Use PostgreSQL 15 or newer unless upstream ChiefOnboarding documents a
  stricter requirement.
- Run regular logical or physical backups outside the application chart.
- Use TLS and network policy at the platform layer when required.
- Monitor connection count, disk usage, and slow queries.
- Test restore before depending on backups.

## Validation

The chart validates both bundled and external database modes through:

```bash
make validate-chart CHART=chiefonboarding
```

The CI external database values include a lightweight PostgreSQL deployment so
the k3d behavioral test validates a reachable external database endpoint.
