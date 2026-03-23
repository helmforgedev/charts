# Database Configuration

Uptime Kuma supports two database backends: SQLite (default) and MariaDB (v2.0+).

## SQLite (default)

No configuration needed. Data is stored in `/app/data/` on the PVC.

```yaml
# This is the default — no changes required
database:
  type: sqlite

persistence:
  enabled: true
  size: 2Gi
```

## MariaDB via MySQL Subchart

Use the bundled MySQL subchart as a MariaDB-compatible backend:

```yaml
database:
  type: mariadb

mysql:
  enabled: true
  auth:
    database: uptime_kuma
    username: uptime_kuma
    password: "strong-password"
```

## External MariaDB

Connect to an existing MariaDB instance:

```yaml
database:
  type: mariadb
  external:
    host: mariadb.example.com
    port: "3306"
    name: uptime_kuma
    username: uptime_kuma
    existingSecret: uptime-kuma-db-credentials
    existingSecretPasswordKey: password

mysql:
  enabled: false
```

Create the secret beforehand:

```bash
kubectl create secret generic uptime-kuma-db-credentials \
  --from-literal=password=your-password
```

## Migration

Uptime Kuma does not provide built-in migration between SQLite and MariaDB. Choose your database backend before first deployment.

<!-- @AI-METADATA
@description: Database configuration guide for the Uptime Kuma Helm chart
@type: chart-docs
@chart: uptime-kuma
@path: charts/uptime-kuma/docs/database.md
@date: 2026-03-23
@relations:
  - charts/uptime-kuma/README.md
  - charts/uptime-kuma/values.yaml
-->
