# Database preparation and upgrades

SQLite is the default. Keep the database, uploads and encryption Secret together when backing up or restoring an
identity provider. Selecting PostgreSQL does not migrate an existing SQLite database automatically.

## Bundled PostgreSQL

```yaml
database:
  type: postgresql
postgresql:
  enabled: true
```

The chart uses the HelmForge PostgreSQL subchart. Its administrator installs `citext` for Pocket ID and `pgcrypto` for
the Francis actor runtime during first initialization. Preserve this initialization script when overriding
`postgresql.initdb.scripts`. The application role needs USAGE and CREATE on its schema, but does not need to be a
superuser or have CREATE permission on the database. Database name, user and password references follow the subchart's
actual authentication values.

Initialization scripts run only on a fresh database volume. Prepare an existing database with the DBA before upgrading;
changing init scripts does not apply them retroactively.

## External PostgreSQL

```yaml
database:
  type: postgresql
  host: postgres.example.com
  port: 5432
  name: pocketid
  username: pocketid
  passwordSecret: pocket-id-database
  passwordKey: password
  sslMode: verify-full
  caSecret: postgres-ca
  caKey: ca.crt
postgresql:
  enabled: false
```

Create the password and CA Secrets in the release namespace. External PostgreSQL defaults to `verify-full`, which checks
the certificate chain and server hostname. Omit `caSecret` for a server trusted by the image's root store. Allow the
destination explicitly with `networkPolicy.extraEgress`. Credentials are encoded as URI components and the resulting
connection URL is written to a private memory volume, rather than a ConfigMap or command argument.

Before the first deployment, the DBA must connect to the target database and install both extensions in the
application's search path:

```sql
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
GRANT USAGE, CREATE ON SCHEMA public TO pocketid;
```

The initializer checks prerequisites using a read-only connection before starting the native migration runners. Pocket
ID owns its application migrations; Francis separately owns its actor tables, functions, triggers and views. Do not
reuse a schema managed by a different application or transfer objects away from the application role.

## Failed migrations

Back up before upgrading. An interrupted or failed Pocket ID migration can leave `schema_migrations.dirty` set. The
chart refuses to start against that state. Installing a missing extension does not repair partially applied SQL or clear
migration state. Inspect the failed migration and restore or repair under the upstream migration procedure; the chart
never forces a migration version or clears dirty state automatically.

The chart remains a singleton with PostgreSQL because uploads and other local identity-provider files still require
consistent persistent storage. A database subchart by itself does not establish an application HA deployment.
