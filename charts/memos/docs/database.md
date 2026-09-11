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

When `database.driver=sqlite` and no DSN is set, Memos stores the database under the data directory, typically
`/var/opt/memos/memos_prod.db`.

Do not scale SQLite mode above one replica. The chart blocks that topology.

## PostgreSQL

To provision the maintained HelmForge subchart in the release:

```yaml
database:
  driver: postgres
postgresql:
  enabled: true
```

The chart selects the writable Service and retained application password from the dependency. Its backup, monitoring,
TLS and topology settings remain available under `postgresql`. PostgreSQL and MySQL cannot both be enabled.

For an external server, component mode builds the DSN from an existing password Secret:

```yaml
database:
  driver: postgres
  host: postgres.database.example.com
  passwordSecret: memos-password
  passwordKey: password
  sslMode: verify-full
  caSecret: database-ca
  networkPolicyPeers:
    - ipBlock:
        cidr: 192.0.2.8/32
```

Replace the example IP and hostname. The CA Secret key defaults to `ca.crt`; omit it for certificates already trusted by
the image. External component mode defaults to `verify-full`. Complete DSNs retain their own explicit TLS options.

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
  dsn: postgres://memos:encoded-password@postgres.database.example.com:5432/memos?sslmode=verify-full
```

## MySQL

Set `database.driver: mysql` and `mysql.enabled: true` for the HelmForge dependency. External components use
`database.host`, `database.passwordSecret` and optional `database.caSecret`; their default `database.mysqlTls: true`
verifies the server certificate and hostname. The bundled default is plaintext unless TLS is explicitly configured.

The complete-DSN Secret contract remains available:

```yaml
database:
  driver: mysql
  existingSecret: memos-mysql
  existingSecretKey: dsn
```

Example DSN:

```text
memos:password@tcp(mysql.database.example.com:3306)/memos?tls=true&parseTime=true&charset=utf8mb4
```

## Volume Requirement

Keep persistence enabled even with an external database. Memos can store local assets and instance data in `MEMOS_DATA`,
so database backup alone may not fully protect the instance.

Changing the driver or endpoint is not a data migration. Restore or migrate the native data into the target backend and
validate account, memo and attachment access before switching production traffic. Password Secrets are consumed during
pod startup; coordinate database-side credential changes and an orderly rollout.

When scaling MySQL or PostgreSQL mode above one replica, set `persistence.existingClaim` to a shared data PVC. The chart
blocks scaled external-database releases that would otherwise create one StatefulSet PVC per pod, because those PVCs can
hold divergent local assets.
