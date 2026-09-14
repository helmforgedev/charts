# Upgrades and migration

## Before an upgrade

Read the upstream release notes and verify installed apps support the target
major version. Take a complete integrated backup and practice restoration.
Record the existing image, chart values, application status and external Secret
references. Schedule an outage: the chart uses one writer and Recreate updates.

Nextcloud requires sequential major-version upgrades. First update to the latest
patch of the installed major, then move one major forward. Finish background
migrations before the next major upgrade. The official image refuses downgrades
and major-version skips. Do not bypass those checks or treat a Helm rollback as
a database rollback.

## Rollout behavior

The init container refreshes image-owned configuration fragments and PHP
extensions. The native image entrypoint synchronizes application code and runs
the native upgrade. The persisted `config.php`, instance identity, custom apps
and data remain on the PVC. Cron shares the initialization lock and will not run
against an uninitialized or upgrade-pending database.

Inspect web and cron logs, run `php occ status --output=json` inside the application
container, and verify a user login, WebDAV read/write and existing shares. The
startup probe allows up to 15 minutes for installation/upgrade. If this is
insufficient for a large database, investigate progress before changing probe
settings or repeatedly restarting the instance.

Existing Secret content used as environment variables requires a rollout to take
effect. Bootstrap administrator settings create the first account only. Change
existing passwords through Nextcloud's supported account management commands.

## Migrating from another chart

Do not replace the Helm release in place or adopt an existing database PVC
without understanding the source chart's storage and credential contracts.
Identify the source application version, database engine and version, entire
application data layout, native instance secrets, custom apps and background jobs.
This chart supports PostgreSQL; a MySQL/MariaDB installation needs a separately
planned and verified upstream database conversion before migration.

Stop all source web, cron and queue writers before taking a consistent SQL/files
copy. Restore into a separate release with fresh storage, matching application
version and retained instance configuration. Reconcile the destination database
and Redis endpoints and configure the public URL and trusted proxies. Verify
non-admin login, file contents and IDs, shares, app settings and new writes before
switching traffic. Keep the source frozen and recoverable until acceptance.

Source archives from unrelated backup tools are not automatically in the chart's
integrated backup format. Use an explicit offline migration procedure or convert
and validate the data separately; do not fabricate a completion marker.
