# MariaDB Datadir SubPath

## Summary

MariaDB 2.0.0 changes the default datadir mount to use a data volume
subdirectory:

```yaml
persistence:
  subPath: mysql
```

This keeps ext4 `lost+found` out of `/var/lib/mysql`.

## Why This Changed

Many Kubernetes storage classes format PVCs as ext4. ext4 creates a
`lost+found` directory at the filesystem root. When the PVC root is mounted
directly as `/var/lib/mysql`, MariaDB scans `lost+found` as if it were a
database directory and logs:

```text
Invalid (old?) table or database name 'lost+found'
```

The database can still start, but the log entry repeats on restarts and hides
real operational signal.

## New Installs

Use the default:

```yaml
persistence:
  subPath: mysql
```

The chart mounts the `mysql` subdirectory as `/var/lib/mysql`, so the
filesystem root and its `lost+found` directory remain outside the MariaDB
datadir.

The default path relies on Kubernetes `fsGroup` handling for volume ownership
and does not render a root initContainer. This keeps new installs compatible
with Pod Security `restricted`.

For storage drivers that do not honor `fsGroup` for subPath directories, enable
the explicit preparation initContainer:

```yaml
persistence:
  subPath: mysql
  prepareDataDir:
    enabled: true
```

That opt-in initContainer runs as root with `CHOWN` and `FOWNER`, so it requires
a Pod Security exception and should not be enabled in restricted namespaces.

## Existing Installs

If the existing data lives at the volume root, set:

```yaml
persistence:
  subPath: ""
```

This preserves the previous mount layout. Without this override, MariaDB will
look in the new `mysql` subdirectory and the database can appear empty.

## Migration Option

To adopt the new default for an existing install, migrate the PVC contents from
the volume root into the configured subdirectory before upgrading. The exact
procedure depends on the storage class, backup policy, and maintenance window.

Recommended approach:

1. Take and verify a backup.
2. Stop application writes.
3. Stop MariaDB.
4. Move existing datadir contents into the `mysql` subdirectory, excluding
   filesystem-managed entries such as `lost+found`.
5. Upgrade with `persistence.subPath: mysql`.
6. Validate pod readiness, application connectivity, and logs.

## Validation

After upgrade, check:

```bash
kubectl get pods -n <namespace> -l app.kubernetes.io/instance=<release>
kubectl logs -n <namespace> <statefulset-name>-0 -c mariadb --tail=100
```

Expected result:

- no `Invalid (old?) table or database name 'lost+found'` log entry
- MariaDB readiness succeeds
- application tables are present

<!-- @AI-METADATA
type: chart-docs
title: MariaDB Datadir SubPath
description: Migration and operations guidance for the MariaDB persistence.subPath breaking change

keywords: mariadb, datadir, subPath, lost+found, migration, upgrade

purpose: Explain the MariaDB 2.0.0 datadir subPath behavior and migration options
scope: Chart

relations:
  - charts/mariadb/values.yaml
  - charts/mariadb/DESIGN.md
path: charts/mariadb/docs/datadir-subpath.md
version: 1.0
date: 2026-06-02
-->
