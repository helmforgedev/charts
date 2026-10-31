# Production Guide

Matomo has two production-critical runtime domains: MySQL or MariaDB for
analytics data, and the Matomo application volume for configuration, plugins,
and generated assets. Back up both before upgrades.

## Application Upgrades

Chart 2.5 and later use the bundled MySQL chart's `mysql.standalone` contract.
Before upgrading from 2.4.x or earlier, move retained `mysql.primary.*` values
to `mysql.standalone.*`. The chart deliberately rejects the obsolete path so
persistence settings cannot be ignored silently.

Do not use `--reuse-values` or `--reset-then-reuse-values`. Both retain the
obsolete `mysql.primary` path, while `--reuse-values` can also omit newly
introduced parent maps such as `networkPolicy`. Export the release overrides
with `(umask 077 && helm get values RELEASE -o yaml > retained-values.yaml)` so
the file is created with owner-only permissions. In that file, move every
`mysql.primary` setting to the equivalent `mysql.standalone` path and remove
the `mysql.primary` map. On Helm versions that support `--hide-secret`, preview
with
`helm upgrade RELEASE helmforge/matomo --reset-values -f retained-values.yaml --dry-run --hide-secret`.
Then perform the actual upgrade, without either preview-only flag, with
`helm upgrade RELEASE helmforge/matomo --reset-values -f retained-values.yaml`.
Use this migrated-file upgrade procedure for every affected release, regardless
of Helm version. If `--hide-secret` is unavailable, skip the preview rather than
expose rendered Secret manifests. Keep any remaining sensitive output in a
trusted environment and out of logs. Use an equivalent owner-only creation
method on non-POSIX systems and remove `retained-values.yaml` immediately after
the upgrade.

The default `5.14.2-apache` image contains PHP 8.4.27, including the fixes for
the critical PHP vulnerabilities referenced by the Matomo 5.14.2 security
notice. Use the new immutable Matomo tag rather than relying on a rebuilt older
tag that may remain stale in a node image cache. Verify both the Matomo and PHP
versions after rollout.

The official container only bootstraps `/var/www/html` when `matomo.php` is
absent. Because the chart persists that directory, `persistence.codeSync` is
enabled by default and synchronizes the release files from `/usr/src/matomo`
before the web container starts. The synchronization overwrites image-managed
files without deleting configuration, marketplace plugins, or other files that
exist only on the PVC.

The sync archives the source directory's top-level entries instead of the
directory itself and preserves metadata on existing directories. A non-root init
container can therefore write through an `fsGroup`-prepared volume without
attempting to change the mode or timestamps of the volume root.

The default `Recreate` Deployment strategy stops the old web pod before the new
init container modifies the shared application volume. Treat image upgrades as
a brief maintenance window. A `RollingUpdate` override is safe only when no
serving pod shares application files with the synchronizing pod.

Back up the database and application volume before changing `image.tag`. The
chart deliberately does not run database migrations during every startup;
after the new pod starts, execute `core:update` during a maintenance window:

```bash
kubectl exec -n matomo deploy/matomo -- php /var/www/html/console core:update --yes --no-interaction
```

Disable `persistence.codeSync.enabled` only when another process owns the
application code lifecycle.

## Database

For production, prefer `database.mode=external` with a managed MySQL or MariaDB
service. The bundled MySQL subchart is useful for development and controlled
single-cluster installations.

## Archiving

Enable the chart-managed `archiver` CronJob so reports are precomputed outside
interactive user traffic. Start with the upstream hourly schedule at minute 5
and tune resources when archive runs overlap. Runs that occur before the Matomo
installer creates `config/config.ini.php` exit successfully without archiving.

The archiver uses the same application PVC as the web pod. By default,
`archiver.sameNodeAsMatomo=true` adds required pod affinity so a ReadWriteOnce
volume is not attached from another node. Set it to `false` for storage that is
safe across nodes, or provide `archiver.affinity` to replace the generated
affinity. `archiver.nodeSelector` and `archiver.tolerations` are also available.

## Scaling

The chart allows multiple web replicas, but Matomo installations must ensure
safe shared storage and session handling first. Keep `replicaCount=1` until
those concerns are handled explicitly.

## Reverse Proxy

When Matomo runs behind Ingress or Gateway API, configure trusted proxy headers
inside Matomo after installation so HTTPS and client IP detection are correct.

<!-- @AI-METADATA
type: chart-docs
title: Matomo Production Guide
description: Production operating notes for the Matomo chart
keywords: matomo, production, archiver, mysql
purpose: Explain production concerns for Matomo on Kubernetes
scope: Chart
relations:
  - charts/matomo/values.yaml
path: charts/matomo/docs/production.md
version: 1.1
date: 2026-10-28
-->
