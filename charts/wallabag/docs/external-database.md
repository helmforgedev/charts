<!-- SPDX-License-Identifier: Apache-2.0 -->
# Wallabag with an External PostgreSQL

Use an external PostgreSQL server, such as a managed cloud database, by
disabling the bundled subchart.

## Prepare the database

Create an empty database and a user that owns it:

```sql
CREATE ROLE wallabag WITH LOGIN PASSWORD 'change-me';
CREATE DATABASE wallabag OWNER wallabag;
```

The user must be able to create tables in the `public` schema; on PostgreSQL 15
and later this requires database ownership or an explicit
`GRANT CREATE ON SCHEMA public TO wallabag`.

## Store the password

```bash
kubectl create secret generic wallabag-db --from-literal=password='change-me'
```

## Values

```yaml
postgresql:
  enabled: false

database:
  external:
    host: pg.internal.example.com
    port: "5432"
    name: wallabag
    username: wallabag
    existingSecret: wallabag-db
    existingSecretPasswordKey: password
```

`database.external.password` is also accepted; the chart then stores it in
`<release>-wallabag-db`. Rendering fails when the host or both password options
are missing.

## First start

The `setup` init container waits up to `setup.databaseWaitTimeoutSeconds` for
the server, installs the schema when it is missing, and configures the initial
super-admin. Follow it with:

```bash
kubectl logs deploy/<release>-wallabag -c setup -f
```

A complete example is in
[../examples/external-database.yaml](../examples/external-database.yaml).

## Backups

The backup CronJob reuses these connection settings. Override them under
`backup.database.*` when backups must use a different host or user, for example
a read replica. See [backup-restore.md](backup-restore.md).
