# PostGIS and Redis

Both dependencies are required. Select each independently: enable the HelmForge
subchart or disable it and configure the corresponding external connection.
Conflicting bundled and external connection settings fail Helm rendering.

## Bundled PostGIS

HelmForge PostgreSQL 2.0.5 runs the official PostGIS image, pinned by manifest digest.
The selected `18-3.6` image contains PostgreSQL 18.6 and targets amd64. The database
Pod is scheduled accordingly. An ARM-only cluster needs external PostGIS; the chart
does not silently substitute an unofficial ARM database image.

The DBA init script installs `postgis` and `pgcrypto` in the application database.
The application role owns application objects and runs migrations without being a
superuser. The image is read-only, with bounded temporary and socket volumes. The
subchart sets PGDATA explicitly inside its persistent data mount.

Bundled connections use authenticated plaintext inside the configured namespace
network boundary. Bundled TLS overrides are rejected; use the external contract for
verified database TLS.

## External PostGIS

Disable `postgresql.enabled` and configure `database.host`, `port`, `name`,
`username`, `passwordSecret` and `passwordKey`. Install both extensions as DBA before
installing the application. The application role needs privileges to create and
migrate its own objects; avoid granting superuser privileges to make an extension
error disappear.

External TLS defaults to enabled and uses libpq `verify-full`. An explicit CA Secret
is required through `database.tls.caSecret` and `caKey`. The hostname must match the
certificate. No insecure hostname or CA bypass is introduced by the chart.

## Redis

The bundled HelmForge Redis runs standalone with authentication, persistence and
`noeviction`. Cache and Sidekiq queues use distinct logical databases, configured by
`cache.database` and `cache.queueDatabase`. Redis Cluster is outside this contract.

External Redis uses `cache.host`, `port`, `username`, `passwordSecret` and
`passwordKey`. Credentials are encoded into the native URI without changing their
meaning; punctuation in passwords does not become URL syntax. Optional TLS verifies
the server certificate and hostname. A custom `cache.tls.caSecret` augments the image
CA bundle for Ruby/OpenSSL processes. This additional trust is process-wide; it is
not a per-connection certificate pin.

The bundled Redis dependency does not expose Pod token automount in its released
values contract. Its dedicated account has no RBAC grants and its NetworkPolicy
denies egress. The production example shares the parent ServiceAccount, whose
automount is disabled, so Redis also inherits that setting.

## Network access and upgrades

Set `networkPolicy.extraEgress` for external endpoints. Default egress allows DNS and
the bundled database/cache peers, and does not enable general Internet access.
Reverse-geocoding providers are unset by default; configure credentials and the
provider's required egress explicitly if using them.

Native schema and data migration commands run sequentially, before web and worker
start. Existing imports with pending migration `20260125100000` require operator
review: that upstream historical backfill compares an integer source column with
string names and rescues the resulting error. The chart blocks that affected upgrade
instead of treating a successful CLI exit as proof that historical backfill ran.
An empty new installation has no historical imports to backfill.
