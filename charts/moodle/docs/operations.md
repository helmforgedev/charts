# Moodle operations

## Runtime contract

This chart deploys Moodle 5.2.2 using MoodleHQ's PHP 8.4 Apache runtime.
MoodleHQ publishes a development-oriented PHP environment, not a packaged LMS.
The chart supplies the production configuration and the separately verified
Moodle application. It does not use the development Compose configuration.

The default runtime manifest and application archive are pinned independently.
Changing only a PHP tag does not change a digest-pinned runtime. Changing a
Moodle application version requires updating the archive URL and checksum
together, then following the database upgrade workflow.

Every pod prepares its own application code into an emptyDir. The archive is
downloaded over HTTPS, checked against the configured SHA-256, and extracted
before execution. Application containers mount this directory read-only.
Restarts never replace code with the latest upstream branch.

The first start requires outbound HTTPS and enough temporary space for the
archive and extracted application. Subsequent pod replacements repeat the
verified preparation. Mirror the exact archive bytes for restricted networks,
or use an immutable custom image as described below.

## Filesystem layout

| Path | Ownership | Durability |
| --- | --- | --- |
| /var/www/html | Prepared upstream code, read-only to workloads | Recreated per pod |
| /var/www/html/config.php | Chart configuration, outside public root | Recreated from ConfigMap |
| /var/www/html/public | Apache document root | Read-only |
| /var/moodledata | Uploaded files and shared application state | PVC by default |
| /var/moodledata/cache | Shared Moodle cache | Same data PVC |
| /var/moodledata/temp | Shared temporary operations | Same data PVC |
| /tmp/moodle-localcache | Node-local cache | Per-container emptyDir |
| /tmp/moodle-requests | Per-request temporary files | Per-container emptyDir |
| /opt/helmforge | Runtime configuration and scripts | Read-only ConfigMap |

Moodle CLI scripts remain under `/var/www/html/admin/cli`. Moving the web root
to `public/` does not move these scripts. Moodle data is never under the HTTP
document root.

## Installation

Default installation creates a PostgreSQL database and an administrator Secret.
The installer waits for an authenticated database connection, rather than
assuming an open TCP port means database initialization has finished.

A connection-scoped advisory lock serializes installation across replicas
(PostgreSQL advisory locks or MySQL/MariaDB GET_LOCK). The lock is
held while the upstream `install_database.php` runs. It is released when the
connection closes, including abnormal termination.

`database.connectTimeout` bounds the combined wait for database connectivity and
the installer lock. Size it for the complete first installation when starting
multiple replicas together. The HA example uses 600 seconds; allow a longer
Helm timeout, such as `--timeout 15m`, for downloads and schema creation.

Installation creates schema only when the Moodle configuration table is absent.
It never drops existing tables. A partial installation fails for administrator
inspection rather than trying to erase and recreate a database.

The installer compares the database version to `public/version.php` on every
startup. A mismatch blocks normal startup with an explicit maintenance message.
Moodle upgrades and downgrades do not run implicitly in web pods.

The chart uses the upstream GPL license agreement option for unattended
installation. Deploying the application accepts its upstream license; the chart
itself remains Apache-2.0.

## Administrator credentials

Use a Kubernetes Secret in production:

```bash
kubectl -n learning create secret generic moodle-admin \
  --from-file=admin-password=./admin-password.txt
```

Reference it with:

```yaml
moodle:
  existingSecret: moodle-admin
  existingSecretPasswordKey: admin-password
```

The bootstrap password is injected only into the installer container. Changing
it later does not reset an installed administrator account. Reset passwords
through Moodle's administrative interface or upstream CLI.

For disposable installations, leaving `adminPassword` empty generates a strong
password. The generated Secret is retained on uninstall and reused by Helm
lookup. Preserve it together with database credentials and the data volume.

Render-only GitOps workflows cannot use live lookup. Supply `existingSecret`
for deterministic reconciliation instead of relying on generated credentials.

## Cron and ad-hoc work

The default cron sidecar invokes upstream `admin/cli/cron.php --keep-alive=0`
at least once per minute when the preceding invocation finishes within a minute.
Long-running tasks finish before another invocation starts in the same pod.
Moodle's database locks coordinate task execution across web replicas.

Cron has its own resource requests and limits. Sharing the pod makes the
default RWO data volume safe: web and scheduled tasks run on the same node and
read the exact same code and configuration.

```bash
kubectl -n learning logs deployment/moodle -c cron --tail=100
```

Successful cycles update `/tmp/moodle-task-last-success` inside the cron
container. This is a local troubleshooting marker, not a durable audit log or
a claim that every scheduled task succeeded.

For task-heavy sites, enable an additional ad-hoc worker:

```yaml
adhoc:
  enabled: true
  keepAlive: 55
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: "2"
      memory: 2Gi
```

The worker uses upstream concurrency controls. It does not pass `--ignorelimits`.
Inspect failed tasks in Moodle's task administration pages and application logs.

The shell supervisor forwards termination signals. Kubernetes may interrupt an
in-flight task when a pod is replaced. Before maintenance or upgrades, drain
tasks through the upstream cron controls rather than assuming the pod grace
period guarantees every task can finish.

## Controlled upgrade

Read the target Moodle release's upgrade prerequisites first. The chart does
not make an unsupported multi-major upgrade safe. Moodle 5.2 requires an
upgrade source supported by its release notes.

1. Verify that a restore-tested database and moodledata backup exists.
2. Record the current chart values, code digest, archive checksum and plugins.
3. Stop new cron work and wait for running tasks to finish.
4. Enable Moodle maintenance and drain external traffic.
5. Set `maintenance.enabled=true`, a unique run ID and `action=upgrade` with
   the target code. Web/task replicas become zero; the maintenance Job uses
   the same application configuration and data PVC.
6. Inspect the Job result and logs. A failed operation leaves maintenance on.
7. Run a separate `action=disable` Job with a new run ID after verification.
8. Set `maintenance.enabled=false`, restore desired replicas and enable cron.
9. Verify login, a representative course, file downloads and scheduled tasks.

Drain tasks while the current deployment is still running:

```bash
kubectl -n learning exec deployment/moodle -c moodle -- \
  php /var/www/html/admin/cli/cron.php --disable-wait=600
kubectl -n learning exec deployment/moodle -c moodle -- \
  php /var/www/html/admin/cli/maintenance.php --enable
```

Commit the intended target version to your deployment values. A maintenance
override can then contain:

```yaml
maintenance:
  enabled: true
  action: upgrade
  runId: upgrade-522
  activeDeadlineSeconds: 1800
```

Use Helm's job wait explicitly:

```bash
helm upgrade moodle oci://ghcr.io/helmforgedev/helm/moodle \
  -n learning -f production-values.yaml -f maintenance-values.yaml \
  --wait --wait-for-jobs --timeout 30m
kubectl -n learning logs job/moodle-maint-upgrade-522 -c maintenance
```

The Job has zero retries. Inspect a failed migration before changing its run ID.
Reusing a run ID with changed pod content is rejected by Kubernetes because
Jobs are immutable. Use a new ID for every deliberate operation.

After a successful upgrade, run `action=disable` with another run ID. The upgrade
Job intentionally does not disable maintenance automatically. Re-enable cron:

```bash
kubectl -n learning exec deployment/moodle -c moodle -- \
  php /var/www/html/admin/cli/cron.php --enable
```

The database remains on the new schema after a Helm rollback. To revert an
incompatible upgrade, restore database and moodledata together and deploy the
matching old code/configuration. Never use Helm rollback as a database restore.

## Health and observability

The chart distinguishes three checks:

- `/healthz.php` proves Apache executes PHP; liveness avoids restarting all
  web pods during a temporary database outage.
- `/readyz.php` checks installed database version against deployed code and
  the CLI maintenance marker.
- `admin/cli/checks.php` reports Moodle operational checks, including task
  freshness. Its warnings are not suitable for restarting containers.

```bash
kubectl -n learning exec deployment/moodle -c moodle -- \
  php /var/www/html/admin/cli/checks.php
```

Apache access logs and PHP errors go to stdout/stderr. Collect cron and worker
logs independently. Monitor database availability, PVC utilization, PHP process
memory, request latency, queue age and scheduled-task failures.

Enable `metrics.enabled` for authenticated application metrics through the
pinned `tool_monitoring` plugin. See the [observability guide](observability.md)
for its private listener, ServiceMonitor and optional PrometheusRule. Continue
using Kubernetes and database monitoring for infrastructure signals.

The bundled behavioral smoke checks health bodies, a rendered login form,
private-path protection and filesystem permissions:

```bash
kubectl -n learning exec deployment/moodle -c moodle -- \
  php /opt/helmforge/smoke.php moodle 80
```

## Immutable plugins and offline code

Browser-based code deployment is disabled by default. Build reviewed plugins,
themes and matching language packs into an immutable application image. Preserve
upstream licenses and include the complete Moodle 5.2 code tree at `/opt/moodle`.

Use the same image for web, initialization, cron and maintenance. The chart
automatically shares its image settings across those components.

```yaml
source:
  mode: image
  imagePath: /opt/moodle
```

Set `image.repository`, `image.tag` and `image.digest` to the verified custom
image. The image must retain the official runtime's Apache, PHP extensions,
curl and tar. Supply an exact digest; the chart does not build or publish it.

Code is copied to the per-pod code volume and mounted read-only by consumers.
No Composer or plugin installation occurs during production requests.
Plugin database migrations are also part of the explicit upgrade workflow.

For archive mode behind an internal mirror, change `source.url` while retaining
the original checksum. A mismatch fails before the package is extracted.
Never fetch the expected checksum from a mutable endpoint during pod startup.
