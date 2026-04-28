# Gophish Database

Research date: 2026-04-28

## Supported Modes

Gophish supports SQLite by default and MySQL through `config.json`.

The initial HelmForge chart should support:

- `sqlite`
- `mysql`
- `external`
- `auto`

PostgreSQL is not part of the upstream documented database model for Gophish and should not be exposed as a chart mode unless upstream support is confirmed in a later phase.

## SQLite

Upstream defaults:

```json
{
  "db_name": "sqlite3",
  "db_path": "gophish.db"
}
```

Because `db_path` is relative, the official container resolves the database file under the working directory `/opt/gophish`.

Chart decisions:

- SQLite is the default chart mode.
- SQLite requires `replicaCount: 1`.
- SQLite should use a PVC by default.
- The chart should prefer an explicit path such as `/opt/gophish/data/gophish.db` if runtime validation confirms permissions.
- The chart must fail fast when SQLite is combined with multi-replica settings.

Recommended values shape:

```yaml
database:
  mode: auto
  sqlite:
    path: /opt/gophish/data/gophish.db

persistence:
  enabled: true
  size: 5Gi
```

## MySQL

The upstream user guide documents MySQL using:

```json
{
  "db_name": "mysql",
  "db_path": "username:password@(host:port)/database?charset=utf8&parseTime=True&loc=UTC"
}
```

The upstream guide also documents MySQL compatibility requirements:

- create the `gophish` database with `utf8mb4`
- remove `NO_ZERO_IN_DATE` and `NO_ZERO_DATE` from MySQL `sql_mode`

The example database creation command is:

```sql
CREATE DATABASE gophish CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

Chart decisions:

- Use HelmForge MySQL dependency for embedded mode.
- Support external MySQL-compatible databases.
- Store DSNs in a Secret, not a ConfigMap.
- Prefer `existingSecret` for production.
- Avoid logging rendered DSNs.

## Mode Detection

Recommended `database.mode: auto` precedence:

| Priority | Condition | Result |
| --- | --- | --- |
| 1 | `database.external.existingSecret` or `database.external.host` | external MySQL |
| 2 | `mysql.enabled: true` | HelmForge MySQL dependency |
| 3 | none | SQLite |

Invalid combinations should fail at render time:

- `database.mode: sqlite` with `mysql.enabled: true`
- `database.mode: mysql` with `database.external.host`
- `database.mode: external` with `mysql.enabled: true`
- `replicaCount > 1` with SQLite
- `database.mode: auto` with multiple database signals

## External Database

Recommended values shape:

```yaml
database:
  mode: external
  external:
    vendor: mysql
    host: mysql.database.svc.cluster.local
    port: 3306
    name: gophish
    username: gophish
    existingSecret: gophish-db
    existingSecretDsnKey: dsn
```

The Secret should contain a complete Gophish-compatible DSN:

```text
gophish:password@(mysql.database.svc.cluster.local:3306)/gophish?charset=utf8&parseTime=True&loc=UTC
```

Inline password values may be useful for local tests, but production examples should prefer an existing Secret.

## Embedded MySQL

Use the HelmForge MySQL chart as an optional dependency.

Implemented `Chart.yaml` dependency:

```yaml
dependencies:
  - name: mysql
    version: 1.8.7
    repository: oci://ghcr.io/helmforgedev/helm
    condition: mysql.enabled
```

Gophish `0.12.1` stores zero-date bootstrap values that MySQL 8.4 rejects under strict zero-date modes. The chart sets embedded MySQL configuration to keep runtime behavior compatible:

```yaml
mysql:
  config:
    myCnf: |
      [mysqld]
      sql_mode=NO_ENGINE_SUBSTITUTION
```

This was validated in k3d after an initial failure with `Incorrect datetime value: '0000-00-00' for column 'last_login'`.

## Config Rendering

The official image only exposes `DB_FILE_PATH` for changing `db_path` through the entrypoint. It does not expose all fields needed for MySQL mode.

Chart decision:

- Render a full `config.json` Secret for all modes.
- Set `db_name` and `db_path` explicitly.
- Avoid relying only on `DB_FILE_PATH`.
- Keep `migrations_prefix` as `db/db_`.

## Backup Boundary

Initial backup stance:

| Mode | Backup stance |
| --- | --- |
| SQLite | Chart-managed backup should archive the SQLite database and any chart-managed runtime files on the PVC. |
| Embedded MySQL | Backup must either use a chart-managed dump job or clearly delegate database backup to the MySQL dependency with documented evidence. |
| External MySQL | External database backup is the operator responsibility unless a chart-managed external dump path is implemented. |

If S3 upload is implemented, HelmForge policy requires `docker.io/helmforge/mc:1.0.0` or a newer pinned HelmForge uploader image.

Backup changes must be validated at runtime, not only rendered.

## Migration Notes

SQLite to MySQL should be documented as an explicit maintenance activity:

1. stop campaign traffic
2. back up the SQLite database and related runtime files
3. create and configure the target MySQL database
4. migrate data using an operator-approved procedure
5. switch Helm values to MySQL mode
6. deploy and validate admin login, campaigns, landing pages, results, and SMTP profiles

The chart should not silently migrate database modes during a normal upgrade.

## References

- Gophish default config: https://raw.githubusercontent.com/gophish/gophish/v0.12.1/config.json
- Gophish installation guide: https://github.com/gophish/user-guide/blob/master/installation.md
- Gophish Docker entrypoint: https://raw.githubusercontent.com/gophish/gophish/v0.12.1/docker/run.sh
- HelmForge backup patterns MCP resource
- HelmForge dependency policy MCP resource

<!-- @AI-METADATA
type: chart-docs
title: Gophish - Database Research
description: Database mode research and decisions for the Gophish HelmForge chart

keywords: gophish, sqlite, mysql, database, helm

purpose: Define database modes, config rendering, and backup boundaries
scope: Chart Research

relations:
  - charts/gophish/docs/architecture.md
  - charts/gophish/docs/security.md
path: charts/gophish/docs/database.md
version: 1.0
date: 2026-04-28
-->
