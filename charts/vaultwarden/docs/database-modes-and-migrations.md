# Database Modes and Migrations

## Supported modes

The chart supports four effective database modes:

- `sqlite`
- `external`
- `postgresql`
- `mysql`

With `database.mode=auto`, selection follows this precedence:

1. `database.external.host` or `database.external.existingSecret`
2. `postgresql.enabled=true`
3. `mysql.enabled=true`
4. SQLite fallback

## Recommended production posture

For production, prefer:

- `database.external`
- or a consciously chosen local `postgresql` or `mysql` subchart

SQLite remains useful for:

- small environments
- disposable environments
- very simple self-hosted deployments

But it should not be the default recommendation when a real database service is available.

## External database mode

There are two valid patterns:

1. Provide structured connection values:

```yaml
database:
  mode: external
  external:
    vendor: postgres
    host: postgresql.example.svc
    port: 5432
    name: vaultwarden
    username: vaultwarden
    password: change-me
```

2. Provide a complete `DATABASE_URL` through an existing secret:

```yaml
database:
  mode: external
  external:
    existingSecret: vaultwarden-database
    existingSecretUrlKey: database-url
```

## Local PostgreSQL and MySQL subcharts

These subcharts are convenience options inside the same release.

They are useful when:

- you want one Helm release to stand up the full stack
- you accept the operational coupling between app and database lifecycle

They are less ideal when:

- the database should have its own lifecycle
- database upgrades and restore operations should remain fully independent
- the environment already has a managed PostgreSQL or MySQL service

## Conflict rules

This chart fails fast when storage selection is ambiguous.

Examples of invalid combinations:

- `database.mode=sqlite` with `postgresql.enabled=true`
- `database.mode=external` with `mysql.enabled=true`
- `database.mode=postgresql` with `database.external.host`
- `database.mode=auto` with both `postgresql.enabled=true` and `mysql.enabled=true`

## Migration strategy

Treat database migration as a maintenance event, not as an implicit chart upgrade side effect.

### SQLite to PostgreSQL or MySQL

Recommended sequence:

1. stop user traffic
2. create a verified backup of `/data`
3. export or migrate the data into the target database
4. prepare the new database mode values
5. deploy Vaultwarden with the new mode
6. validate login, organizations, attachments, sends, and admin access

Keep the original `/data` backup until the new deployment is fully validated.

### External database to another external database

Recommended sequence:

1. freeze writes
2. back up the source database and `/data`
3. migrate the database contents
4. switch `database.external.*` or the referenced `DATABASE_URL` secret
5. redeploy and validate application behavior

### Subchart to managed external database

Recommended sequence:

1. back up the database and `/data`
2. migrate data out of the subchart-managed database
3. disable the subchart
4. configure `database.external`
5. redeploy and validate

Do not delete the old database resources before validation completes.

## Restore guidance by mode

### SQLite

Restore the full `/data` state boundary:

- `db.sqlite3`
- `config.json`
- `rsa_key*`
- `attachments/`
- `sends/`

### PostgreSQL / MySQL

Restore both:

- the database contents
- the `/data` filesystem artifacts that remain outside the database

External DB mode reduces the role of SQLite, but it does not eliminate the need to preserve `/data`.

For a deeper backup model for these modes, review [External Database Backup](external-database-backup.md).

## Validation after migration or restore

At minimum, validate:

- login flow
- organization access
- attachment download
- send access
- admin panel access
- email and invitation behavior
- generated links using the configured `domain`

## References

- Vaultwarden configuration template: https://raw.githubusercontent.com/dani-garcia/vaultwarden/main/.env.template
