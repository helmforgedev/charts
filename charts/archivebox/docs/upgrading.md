# ArchiveBox Upgrade and Migration Guide

## Review Chart Values First

This chart aligns with ArchiveBox 0.9.x deployment behavior. Before upgrading,
review your saved values and the rendered Deployment. Removed settings fail
validation instead of being silently ignored:

- Rename `archivebox.publicAddLinks` to `archivebox.publicAddPage`. The upstream
  variable remains `PUBLIC_ADD_VIEW` and the default remains `False`.
- Remove `archivebox.publicSnapshots`. Snapshot visibility is configured through
  the UI and `PERMISSIONS`. If the old value was `False`, preserve private
  capture defaults explicitly before removing it. `publicIndex: "False"`
  hides the index but is not equivalent to private snapshots.
- Set `archivebox.baseUrl` to the public canonical URL, or verify the value
  inferred from the first ingress host and its matching TLS configuration.
  Replace old CSRF-only ingress examples with `BASE_URL` configuration.
- Review `archivebox.serverSecurityMode`. `auto` gives ordinary public hosts
  single-domain replay without JavaScript; isolated full replay requires
  explicit subdomain mode and wildcard ingress, DNS, and TLS.
- Review custom `securityContext` and `podSecurityContext` overrides. The new
  default starts the upstream entrypoint as root and drops privileges for the
  application. Remove stale fixed UID/GID overrides if you want autodetection,
  or set `archivebox.puid` / `archivebox.pgid` for storage with fixed identities.
- Sonic is now the default search backend and runs inside the application
  container. Reindex existing captures when switching from another backend.

For example, an installation that previously used `publicSnapshots: "False"`
can preserve the global default for new captures with:

```yaml
archivebox:
  publicIndex: "False"
  publicAddPage: "False"
  extraEnv:
    - name: PERMISSIONS
      value: private
```

Check existing snapshot and Persona permissions in the UI as well. Removing a
legacy chart key does not retroactively rewrite every snapshot's permissions.

Avoid blindly using `--reuse-values`: Helm retains removed keys and previous
security defaults. Start with reviewed replacement values instead, preserving
existing Secret and PVC references and all other intentional overrides:

```bash
helm upgrade <release> helmforge/archivebox --reset-values -f reviewed-values.yaml
```

## Protect the Full Collection

Before any application or filesystem migration:

1. Stop the old ArchiveBox server and all other writers.
2. Take and verify a complete off-cluster backup of `/data`, including the
   database, configuration, Personas, and archived files. With PostgreSQL,
   include a coordinated database backup too.
3. Keep that backup until the upgraded collection has been verified.

The chart's live tar CronJob alone is not a consistent backup guarantee. See
[the backup guide](backup.md). Helm rollback does not reverse database schema
or filesystem changes. Restore the entire matching recovery point when an
application downgrade requires older data.

## Upgrading a 0.7.x Collection

Upstream 0.9 changes both the database and the archive filesystem layout. After
stopping the old server and backing up, run these commands with the new image
against the same collection, with the production server stopped:

```bash
archivebox init
archivebox update --migrate-only
```

Use a one-off maintenance workload with the same PVC, credentials, and required
runtime settings. Do not run two ArchiveBox instances against that volume.
Database migrations may take minutes to hours on a large collection. Increase
the startup probe budget if migration runs as part of server startup; the
standard budget may be too short. Prefer completing a long migration in the
maintenance workload before starting the web server.

Verify login, representative old snapshots, captured files, search, and a new
capture after the migration. The
[0.9 release instructions](https://github.com/ArchiveBox/ArchiveBox/releases/tag/v0.9.36)
and [filesystem migration clarification](https://github.com/ArchiveBox/ArchiveBox/releases/tag/v0.9.64)
explain the layout change and recovery precautions.

## Switching to PostgreSQL

`externalDatabase.enabled` selects a different main-index backend; it does not
copy existing SQLite records to PostgreSQL. Provision the PostgreSQL server,
database, role, and password Secret, then perform and test a separate data
migration before switching an existing collection. A fresh PostgreSQL database
will not automatically contain the SQLite collection's records.

`/data` remains required for artifacts, configuration, Personas, and local
indexes. PostgreSQL does not enable multiple application replicas in this chart,
and its backup must be managed separately from the data-volume CronJob.
