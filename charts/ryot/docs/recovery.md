# Ryot database operations and recovery

Back up PostgreSQL with its native tools and retain the administrator override and initial-password Secrets separately.
The initial password is not an account reset mechanism; actual password hashes and sessions live in the database.

## Before upgrading

1. Record the application and PostgreSQL versions, database endpoint, extension versions and retained Secret names.
2. Stop the Ryot writer for a consistent recovery checkpoint when migrations or queued operations are involved.
3. Create a custom-format pg_dump using the database's supported client version and protect the resulting archive.
4. Verify restoration into a separate empty database before applying irreversible application migrations.
5. Upgrade with the same credentials, inspect admission/migration logs and authenticate before reopening ingress.

The chart's PostgreSQL first-boot scripts prepare uuid-ossp and pg_trgm only on a new data volume. For external
databases, have the DBA prepare these extensions and grant application schema privileges. Do not make the application
role a superuser to bypass migration setup.

## Restore validation

Restore the native dump into an empty database with the intended application owner and extensions. Point the chart at
that database using the same retained authentication Secret and a verified TLS connection when external. The admission
check must pass without modifying existing users. Verify an existing native session, local password login and private
tracking data before directing user traffic to the recovered deployment.

The automated profile uses an independent empty database on its disposable PostgreSQL server, preserves the original
database, then checks the original session and a Unicode collection. It proves logical database recovery, not multi-node
failover. Production backup storage, retention and recovery-point objectives remain deployment responsibilities.

Application temporary import files and in-memory background jobs are not part of the PostgreSQL recovery boundary. Helm
rollback does not reverse data migrations. Do not restore an OIDC-linked database into this local-only chart.
