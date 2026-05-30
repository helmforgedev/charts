# JupyterHub Production Notes

## Authentication

Do not expose the default DummyAuthenticator without a password. For production, set `auth.type=custom` and configure an authenticator in `hub.extraConfig`.

## Persistence

The default Hub state uses a SQLite database on the Hub PVC. Keep Hub replicas
at one for this mode. For larger deployments, configure JupyterHub to use an
external database in `hub.extraConfig` and manage that database with the
HelmForge PostgreSQL chart.
The chart fails rendering when `hub.replicaCount > 1` and no external
`c.JupyterHub.db_url` is configured, because SQLite is single-writer storage.
For HA Hubs without Hub persistence, create a shared Secret containing the
hex-encoded JupyterHub cookie secret and set `hub.cookieSecret.existingSecret`.
Without that shared file, each replica generates its own secret and
load-balanced login sessions can fail when requests land on another replica.
Because the chart runs configurable-http-proxy separately from the Hub, it sets
`c.JupyterHub.cleanup_servers = False` by default through
`hub.cleanupServers=false`. Keep this default to preserve running user servers
across Hub rollouts, checksum-triggered restarts, and node drains.

## Single-User Pods

Use `singleuser.profiles` to offer controlled notebook profiles. Enable `singleuser.storage.enabled=true` when users need persistent home directories.
