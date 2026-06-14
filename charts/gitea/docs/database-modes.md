<!-- SPDX-License-Identifier: Apache-2.0 -->

# Database Modes and Secrets

Gitea supports SQLite, PostgreSQL, and MySQL. The chart can use SQLite without
extra values, deploy a HelmForge database subchart, or connect to an existing
database endpoint.

## Auto Mode

`database.mode: auto` selects the database from the configured values:

1. External database when `database.external.host` or
   `database.external.existingSecret` is set.
2. PostgreSQL subchart when `postgresql.enabled=true`.
3. MySQL subchart when `mysql.enabled=true`.
4. SQLite when no database source is configured.

Only one source can be active. The chart fails template rendering when multiple
sources are set or when an explicit mode lacks its required settings.

## SQLite

SQLite is the default and stores data at `database.sqlite.file`, which defaults to
`/var/lib/gitea/data/gitea.db`.

```yaml
database:
  mode: sqlite
persistence:
  enabled: true
  size: 20Gi
```

Keep `replicaCount: 1` with SQLite. For production teams with multiple writers or
high repository traffic, move to PostgreSQL or MySQL before scaling.

## PostgreSQL Subchart

```yaml
database:
  mode: postgresql
postgresql:
  enabled: true
  auth:
    database: gitea
    username: gitea
    password: "change-me"
```

The Gitea pod waits for `<release>-postgresql:5432` before starting.

## MySQL Subchart

```yaml
database:
  mode: mysql
mysql:
  enabled: true
  auth:
    database: gitea
    username: gitea
    password: "change-me"
    rootPassword: "change-root"
```

The Gitea pod waits for `<release>-mysql:3306` before starting.

## External Database

```yaml
database:
  mode: external
  external:
    vendor: postgres
    host: postgres.database.svc
    port: 5432
    name: gitea
    username: gitea
    existingSecret: gitea-database
    existingSecretPasswordKey: database-password
```

For MySQL, set `vendor: mysql` and use port `3306`.

## Admin Credentials

Set `admin.username` to render the post-install admin creation Job. The password
comes from `admin.existingSecret`, `admin.password`, or a generated chart-managed
secret.

```yaml
admin:
  username: gitea_admin
  email: admin@example.com
  existingSecret: gitea-admin
```

The existing secret must contain:

| Key | Purpose |
| --- | --- |
| `admin-username` | Admin username. |
| `admin-password` | Admin password. |
| `admin-email` | Admin email address. |

## External Secrets

External Secrets integration is limited to admin credentials. When enabled,
`admin.existingSecret` is required to prevent both the chart and External Secrets
Operator from writing different credentials to the same target.

```yaml
admin:
  existingSecret: gitea-admin
externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  data:
    - secretKey: admin-username
      remoteRef:
        key: gitea/admin
        property: username
    - secretKey: admin-password
      remoteRef:
        key: gitea/admin
        property: password
    - secretKey: admin-email
      remoteRef:
        key: gitea/admin
        property: email
```
