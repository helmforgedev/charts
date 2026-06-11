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
