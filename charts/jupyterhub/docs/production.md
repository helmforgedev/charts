# JupyterHub Production Notes

## Authentication

Do not expose the default DummyAuthenticator without a password. For production, set `auth.type=custom` and configure an authenticator in `hub.extraConfig`.

## Persistence

The default Hub state uses a SQLite database on the Hub PVC. Keep Hub replicas
at one for this mode. For larger deployments, configure JupyterHub to use an
external database in `hub.extraConfig` and manage that database with the
HelmForge PostgreSQL chart.

## Single-User Pods

Use `singleuser.profiles` to offer controlled notebook profiles. Enable `singleuser.storage.enabled=true` when users need persistent home directories.
