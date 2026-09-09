# Langflow Database

## SQLite Mode

The default mode uses SQLite in `/app/langflow`. This is simple and works for one replica:

```yaml
database:
  mode: sqlite
persistence:
  enabled: true
```

Do not scale SQLite mode horizontally.

The Deployment uses Recreate during upgrades. Stop database writers, take a
backup and start a single new instance to apply Alembic migrations before
scaling out. Database migration failures require investigation and a tested
restore plan; do not run destructive repair against the only data copy.

## External Database

Use a PostgreSQL-compatible external database for production scaling:

```yaml
database:
  mode: external
  existingSecret: langflow-database
```

The Secret must contain:

```text
database-url=postgresql://user:password@postgresql:5432/langflow
```

The chart maps it to `LANGFLOW_DATABASE_URL`.

Changing this URL initializes the target schema but does not copy data from
SQLite. Export/import flows and plan credential recovery separately when
changing database engines.
