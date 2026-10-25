<!-- SPDX-License-Identifier: Apache-2.0 -->

# Ghost Operations

## Deployment and Health

Ghost is intentionally deployed as one replica with `Recreate` strategy because its content directory is normally a
ReadWriteOnce volume. Startup, readiness and liveness probes query `/ghost/api/admin/site/`. Inspect pod events and
container logs when the probes fail, then verify database connectivity before increasing probe thresholds.

## Disruption and Upgrades

Enable `podDisruptionBudget.enabled` to protect the server pod during voluntary node maintenance. This is disruption
protection, not high availability. Before an upgrade, back up both content and MySQL, review the upstream release, and
test themes, integrations, newsletters, comments and member flows in staging.

## Backup and Restore

The optional CronJob archives `/var/lib/ghost/content` to S3-compatible storage. It does not export the MySQL database.
Operate a separate database backup with verified retention. A complete recovery restores the database and content from
the same recovery point, reinstalls the release, and validates the canonical URL plus integrations.

Monitor CronJob failures, object-store capacity and database backup freshness. Test restore procedures regularly; the
existence of backup objects alone is not proof of recoverability.

## Capacity and Observability

Size CPU, memory and the content PVC from observed traffic and media growth. Monitor pod restarts, probe failures,
resource saturation, PVC usage, HTTP errors, database latency and backup completion. The chart emits application logs to
stdout but does not install metrics, log or tracing collectors.

## Custom Listener

Set `containerPorts.http` to change the real Ghost listener. The chart injects `server__port` and uses the same value for
the container, probes, Service target and NetworkPolicy. Directly setting `server__port` through `ghost.extraEnv` is
rejected to prevent a split configuration.
