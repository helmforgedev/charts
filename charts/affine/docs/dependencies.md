# PostgreSQL and Redis

The defaults enable HelmForge PostgreSQL and Redis dependencies. PostgreSQL uses
the official pinned pgvector PostgreSQL 16 image and a DBA initialization script
that installs `vector`. Redis uses password authentication, AOF persistence and
`maxmemory-policy noeviction`. These bundled connections use plaintext within the
configured namespace network boundary.

Bundled Redis uses a dedicated account without RBAC grants and accepts connections
only from this release's AFFiNE Pods when NetworkPolicy is enabled. Its image
filesystem is read-only, capabilities are dropped and seccomp uses RuntimeDefault.
The released Redis dependency does not expose a token-automount setting. To prevent
token projection, set `serviceAccount.name` to a unique release-specific name and
use that same name in `redis.serviceAccount.name`, with
`redis.serviceAccount.create=false`. The production Ingress example and CI profile
exercise this shared, unprivileged account; the AFFiNE account disables token
automount. Redis egress is denied by the parent chart's policy.

For managed services or independently operated databases, disable the relevant
subchart and configure `database.*` or `cache.*`. The two choices are independent.
External TLS is enabled by default. Provide the DNS name present in the server
certificate and an optional Secret containing its CA certificate. If `caSecret`
is empty, the client's system trust applies. Disabling TLS is an explicit decision
for a trusted transport boundary; it does not provide encryption.

The PostgreSQL application user needs permission to run the native schema/data
migrations and own application objects. Have the DBA install `vector` before
startup. An existing unresolved Prisma migration blocks admission; repair it using
the upstream-supported procedure after backup and diagnosis. The chart does not
automatically roll back migration-history records.

## Different PostgreSQL clients

AFFiNE 0.27.4 contains both Prisma and native SQLx connection pools. Their TLS URL
parameters are incompatible. The chart builds separate URLs from the same database
coordinates and credential:

| Client | Encryption, certificate and hostname verification |
| --- | --- |
| Prisma | `sslmode=require&sslaccept=strict`, optional `sslcert` CA file |
| Native SQLx | `sslmode=verify-full`, optional `sslrootcert` CA file |

The application Prisma URL is supplied through native `db.prisma.datasourceUrl`;
`DATABASE_URL` supplies SQLx. Schema and data migrations use the corresponding
environment in separate native commands. Do not inject a common `DATABASE_URL`
through `extraEnv`, or substitute familiar libpq parameters without checking the
specific driver. Connection credentials are URL-encoded before use.

## Redis logical databases

Redis must support database selection. AFFiNE uses base database N for cache,
N+2 for sessions, N+3 for Socket.IO and N+4 for queues. The default base is zero;
ensure the server provides all required databases. This chart supports the validated
standalone endpoint contract and rejects Redis Cluster or unvalidated bundled
replication topologies.

Native ioredis TLS receives the actual CA PEM contents and the configured hostname
with `rejectUnauthorized=true`. This configuration applies to all logical clients,
including sessions and collaboration. Keep noeviction for queue reliability and
size Redis for the expected workload.

## NetworkPolicy and rotation

The default policy permits DNS and bundled dependencies. External services require
appropriate `networkPolicy.extraEgress` entries. Use namespace/pod selectors for
in-cluster services or reviewed CIDRs for managed endpoints. Kubernetes NetworkPolicy
does not resolve arbitrary domain-name allowlists.

Rotate dependency credentials and CAs through a coordinated restart. Replacing a
mounted CA file alone does not guarantee that existing pools reload it. Back up the
matching database, configuration, private key and storage before changing endpoints
or database ownership. Test native login, a persisted document edit and blob bytes
after a change; a TCP connection or one successful PING is insufficient.
