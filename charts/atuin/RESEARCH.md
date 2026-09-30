# Atuin chart research

## Upstream contract

- Stable release: Atuin `18.23.0` (2026-09-22).
- Official image: `ghcr.io/atuinsh/atuin:18.23.0`.
- Verified manifest digest: `sha256:f232feeead54a0a13132b9cd477e312c3380e9dc90f1db24c4f79ce6c8e034ea`.
- Verified platforms: `linux/amd64` and `linux/arm64`.
- Runtime user: UID/GID 1000; entrypoint: `atuin-server`; server argument: `start`.
- Main listener: HTTP 8888. Prometheus listener: HTTP 9001 when enabled.
- Health endpoint: `/healthz`; it follows `ATUIN_PATH` and does not query the database.
- The process handles SIGTERM/SIGINT gracefully and runs embedded database migrations before binding its listener.

## Data and configuration

Atuin requires a SQL database. PostgreSQL 14+ and SQLite are tier-one backends; MySQL is tier two. PostgreSQL is the
production recommendation. SQLite uses WAL and must remain single-replica. Every PostgreSQL replica can open up to 100
connections, so scaling must account for database capacity.

The database URI is a secret and must be supplied through `ATUIN_DB_URI`. The application does not support a file
variant of that variable. `/config` must be writable because Atuin creates `server.toml` when absent. A PVC is required
for SQLite; an `emptyDir` is sufficient with PostgreSQL.

Atuin Server 18.23.0 has no native S3 or object-storage backend. S3 references found in community charts implement
chart-side file backup rather than application storage. This chart will not expose unsupported S3 application settings.

TLS termination belongs at Ingress, Gateway API or another reverse proxy. Upstream warns that credentials are exposed in
clear text without HTTPS.

## Existing charts and gaps

- `atuinsh/helm-charts`: official but marked work in progress, last released in 2024 at application 18.3.0. Its
  PostgreSQL toggle is non-functional and it lacks schema, Gateway API, NetworkPolicy, PDB and product-specific tests.
- `rm3l/helm-charts`: newer community chart but uses the legacy Bitnami PostgreSQL image, unsafe example credentials and
  a file-copy S3 backup that is not a PostgreSQL backup.
- TrueCharts: active and hardened, but requires its common abstraction and CNPG topology, targets Kubernetes 1.33+, and
  does not expose HelmForge contracts.
- `pcmid/charts`: obsolete application and common-chart versions.

## HelmForge design decisions

- Default to a single-replica SQLite deployment with a PVC for a useful, self-contained installation.
- Offer the maintained HelmForge PostgreSQL subchart and an external complete-URI Secret contract.
- Reject multiple replicas or autoscaling with SQLite at template time.
- Keep registration closed by default.
- Mount `/config` and `/tmp` writable while retaining a read-only root filesystem.
- Provide HTTP probes at the prefix-aware health path.
- Expose metrics through a separate ClusterIP Service and optional ServiceMonitor; never route metrics publicly.
- Provide canonical Ingress, Gateway API, External Secrets, NetworkPolicy, PDB and scheduling contracts.
- Treat health as process health; the runtime smoke test must exercise a real database-backed server operation.

## Sources

- <https://github.com/atuinsh/atuin/releases/tag/v18.23.0>
- <https://docs.atuin.sh/latest/self-hosting/server-setup/>
- <https://docs.atuin.sh/latest/self-hosting/docker/>
- <https://docs.atuin.sh/latest/self-hosting/kubernetes/>
- <https://github.com/atuinsh/atuin/blob/v18.23.0/crates/atuin-server/src/settings.rs>
- <https://github.com/atuinsh/atuin/blob/v18.23.0/crates/atuin-server/src/router.rs>
- <https://github.com/atuinsh/atuin/blob/v18.23.0/crates/atuin-server/src/db/postgres/mod.rs>
- <https://github.com/atuinsh/helm-charts>
- <https://github.com/rm3l/helm-charts/tree/main/charts/atuin>
