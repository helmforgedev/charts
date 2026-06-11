# Memos Database

Memos supports SQLite, MySQL, and PostgreSQL.

## SQLite

SQLite is the default chart mode:

```yaml
database:
  driver: sqlite
persistence:
  enabled: true
```

When `database.driver=sqlite` and no DSN is set, Memos stores the database under the data directory, typically `/var/opt/memos/memos_prod.db`.

Do not scale SQLite mode above one replica. The chart blocks that topology.

## PostgreSQL

Use an existing Secret for production:

```yaml
database:
  driver: postgres
  existingSecret: memos-postgres
  existingSecretKey: dsn
```

Example Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: memos-postgres
type: Opaque
stringData:
  dsn: postgres://memos:password@postgresql:5432/memos?sslmode=disable
```

## MySQL

```yaml
database:
  driver: mysql
  existingSecret: memos-mysql
  existingSecretKey: dsn
```

Example DSN:

```text
memos:password@tcp(mysql:3306)/memos
```

## Volume Requirement

Keep persistence enabled even with an external database. Memos can store local assets and instance data in `MEMOS_DATA`, so database backup alone may not fully protect the instance.
