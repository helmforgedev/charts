# PostgreSQL and Redis

## PostgreSQL

The default HelmForge dependency creates the dedicated `twenty` database and non-superuser application role. Its
initialization grants CREATE on that database so native installation can create core and workspace schemas. Native setup
also requires `uuid-ossp`, `unaccent`, `citext` and the immutable unaccent wrapper. The MVP proved these operations
without granting a superuser role or CREATEDB.

For an existing service, disable `postgresql.enabled`, set `database.host`, name, username and password Secret. The
Secret key defaults to `password`. Keep TLS enabled and use a certificate-matching hostname. A CA Secret supplies
additional trust through the native PostgreSQL connection's `verify-full` configuration. The initializer and regular
native processes use the same encoded credentials.

Provision database ownership and schema privileges deliberately before first startup. Native migrations manage schemas;
the chart does not disable migrations to make an incompatible database appear healthy. Initialization checks native
command exit codes and relevant private error output because some upstream commands can log an error while returning
success.

## Redis

The default HelmForge Redis dependency uses authentication, standalone storage, append-only persistence and
`maxmemory-policy noeviction`. Redis holds native cache, PubSub and BullMQ job state; treating it as an expendable cache
loses work. Size memory and disk for queue depth, retention and application caches.

The pinned Redis 2.0.1 dependency requires its default port 6379 for health probes. The chart rejects a custom bundled
port; external Redis supports a custom port.

For external Redis, disable `redis.enabled` and configure `cache.host`, password Secret and optional username/database
index. TLS uses `rediss://`; a CA Secret extends trust for native server, worker and health checks. Authentication
remains required. Native queue and cache clients share this configured endpoint.

The tested ACL identity supports the native cache, PubSub, scripting and BullMQ commands. This is not proof of an
arbitrary restrictive ACL policy. Managed services must support the native command set and retain noeviction semantics.

The external-dependencies acceptance profile passed with the native PostgreSQL and
ioredis clients, including certificate-chain and hostname rejection, Redis wrong-password
rejection and successful controls afterward. Native company creation, attachment bytes,
SDK worker output and retained identity/session checks also passed on that TLS topology.

## Network and Kubernetes identity

Bundled dependency peers are selected by release labels. External services need explicit `networkPolicy.extraEgress`
destinations and ports, including endpoints reached behind a Kubernetes Service. CA trust does not replace network
policy.

The released Redis dependency does not expose a Pod-level token-automount option. Use one explicitly named tokenless
ServiceAccount shared with the dependency when hardening a complete deployment; `ci/production-values.yaml` demonstrates
that configuration for PostgreSQL and Redis. The acceptance profile checks all four application/dependency Pods for
absence of projected API tokens.
