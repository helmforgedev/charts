# Database Modes

The Drupal chart prepares the runtime and storage, but the final site installation is completed through Drupal's installer.

## Bundled MySQL

Default mode:

- `mysql.enabled=true`
- `database.mode=auto`

Use the following values from `NOTES.txt` during installation:

- Database type: `MySQL, MariaDB, Percona Server, or equivalent`
- Database host: `<release>-mysql`
- Database name: `mysql.auth.database`
- Database username: `mysql.auth.username`
- Database password: retrieved from the MySQL auth secret

This is the recommended production path when you do not need horizontal scaling beyond the bundled MySQL defaults.

## External Database

Set:

```yaml
database:
  mode: external
  external:
    host: db.example.com
    port: 3306
    name: drupal
    username: drupal

mysql:
  enabled: false
```

The chart does not create or manage the external database password for the installer flow. Provide your own credentials during installation.

If you also enable chart-managed backups for an external database, set `backup.database.password` or `backup.database.existingSecret`.

## SQLite

Set:

```yaml
database:
  mode: sqlite

mysql:
  enabled: false
```

Recommended installer path:

```text
sites/default/files/.ht.sqlite
```

Use SQLite for lightweight environments, evaluation, or controlled single-replica installs. It is not the recommended production path for most Drupal installations and it cannot be combined with horizontal scaling.
