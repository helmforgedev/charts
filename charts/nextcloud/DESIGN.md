# Nextcloud chart design

## Operating model

The chart runs one Apache application Pod with a co-located PHP cron worker.
The official image synchronizes bundled application code and performs native
installation and sequential major-version upgrades. Recreate updates stop both
writers before replacing the Pod. A ReadWriteMany PVC does not change this
single-writer contract; there is no HPA or horizontal scaling switch.

PostgreSQL holds users, file identities, shares and application state. The complete
`/var/www/html` volume holds native configuration and instance secrets, installed
code, custom apps, themes and user data. Redis provides PHP sessions, distributed
caching and transactional file locking. None of these data domains substitutes
for another in disaster recovery.

## Native image and filesystem

Apache runs as UID/GID 33 on port 8080, with dropped capabilities, runtime-default
seccomp and a read-only root filesystem. An init container copies the image's PHP
extension configuration into a writable volume because the upstream entrypoint
generates Redis session settings there. Writable Apache runtime directories and
temporary files have separate emptyDir mounts.

Image-owned `*.config.php` snippets are refreshed on rollout. Native `config.php`
is retained. A chart-owned final snippet reconciles trusted hosts, proxy settings
and the current database connection. This avoids stale configuration after a
restore or change to an existing Secret reference. Changes to Secret contents
used as environment variables require an application rollout.

Apache does not load the upstream broad private-network RemoteIP trust rule.
Nextcloud receives the real peer address and trusts forwarded headers only from
the explicitly configured proxies. The chart keeps the PHP handler, `.htaccess`
processing, WebDAV methods and protected data/configuration directories.

## Background jobs

Cron runs under the same unprivileged identity, taking a shared lock on the
upstream initialization lock before invoking Nextcloud CLI and `cron.php`.
Uninitialized, maintenance-mode or upgrade-pending instances do not run cron.
The worker exits on execution failure rather than silently reporting success.

## Consistent backup boundary

The backup CronJob has sequential stages: check object storage, acquire the
volume lock and scale the application to zero, wait for every web/cron Pod to
terminate, dump PostgreSQL, archive files, resume the application, and upload the
backup set. A directory created atomically on the application volume serializes
manual jobs as well as scheduled jobs. Application initialization refuses to
start while this lock exists, including during an unsolicited concurrent rollout.
The Apache supervisor records evidence only after the upstream Apache process
finishes a graceful stop. Cron waits for an active PHP task to finish before
recording its own evidence. The coordinator requires both records for the exact
source Pod UID. An OOM, forced kill or exceeded termination deadline therefore
fails closed instead of treating Pod disappearance as a consistent checkpoint.

Only the coordinator stages receive a projected Kubernetes token. RBAC permits
reading/updating the one Deployment scale subresource and listing namespace Pods.
SQL stages receive database credentials; S3 stages receive object-store credentials.
The application itself has no API token. Backup Pod affinity schedules the worker
on the application's node before stopping it, supporting RWO volumes.

Failure during quiescence, SQL dump or archive deliberately retains the lock and
stopped application. This is visible and requires operator recovery. Upload
failure occurs after service resumes and produces no completed backup marker.
Unique object prefixes isolate backup sets. Consumers verify the final marker and
all payload checksums before restoring. Object-store encryption, retention,
replication and lifecycle policies belong to the bucket administrator.

## Restore boundary

Restore mode holds the application at zero replicas. A Job downloads a completed
set, verifies checksums and application version, requires an empty application PVC,
extracts files and restores the SQL dump transactionally into an empty database.
Operators retain the original bootstrap administrator credentials and external
provider Secrets. The restored native instance identity remains on the PVC.
Disable restore mode only after the Job succeeds.

## Deliberate limits

This release supports PostgreSQL and standalone Redis. It does not provision
MySQL/MariaDB, office suites, Talk media relays, full-text search or primary S3
object storage. Primary object storage would require an additional consistent
backup domain. The integrated S3 feature is specifically backup storage.
Application extensions installed through Nextcloud remain operator-managed and
must support the selected upstream major version.
