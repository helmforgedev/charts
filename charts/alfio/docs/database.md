<!-- SPDX-License-Identifier: Apache-2.0 -->

# Database Configuration

alf.io requires PostgreSQL. The chart supports a bundled HelmForge PostgreSQL
subchart and an external PostgreSQL endpoint.

## Bundled PostgreSQL

Bundled PostgreSQL is enabled by default:

```yaml
postgresql:
  enabled: true
  auth:
    database: alfio
    username: alfio
```

Use this mode for local validation, demos, and small installations where the
Helm release can own the database lifecycle.

## External PostgreSQL

Disable the subchart and configure the external endpoint:

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgres.example.com
    port: "5432"
    name: alfio
    username: alfio
    existingSecret: alfio-db
    existingSecretPasswordKey: password
```

The referenced Secret must exist in the release namespace:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: alfio-db
type: Opaque
stringData:
  password: change-me
```

## Startup Behavior

The chart renders an init container that waits for the PostgreSQL host and port.
This prevents the main application container from starting before DNS and the
database listener are ready.

## Backup Responsibility

alf.io stores durable business data in PostgreSQL. The chart does not render an
application-level backup job. Use the PostgreSQL subchart backup pattern if the
database is chart-managed, or the platform database backup process when using an
external PostgreSQL service.
