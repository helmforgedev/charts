# Moodle troubleshooting

## Source download does not finish

Inspect `prepare-code` logs, DNS, HTTPS egress, proxy policy and available disk.
The default archive is downloaded once per pod creation, not on every request.
Use a verified internal HTTPS mirror or an immutable image for offline clusters.

```bash
kubectl -n learning logs deployment/moodle -c prepare-code
kubectl -n learning get events --sort-by=.lastTimestamp
```

## Checksum mismatch

Do not disable checksum verification. Check whether the URL points to a weekly
or mutable package rather than the intended stable release. Compare the bytes
against the official release checksum and investigate the mirror/cache.

## Database initialization wait

Inspect the selected database's authenticated readiness and its initialization logs. Verify the selected
Secret/key and database/user values. A TCP connection alone does not prove the
application user and schema have been created.

For external databases, check NetworkPolicy, TLS CA and certificate hostname.
The wait is bounded by `database.connectTimeout`.

## Installer reports existing tables

The database may contain a partial installation or unrelated schema. Inspect it
before doing anything destructive. Use a dedicated empty database for a new
site, or restore a complete existing Moodle database and set `autoInstall=false`.

## Database and code version mismatch

Normal pods do not run upgrades automatically. Confirm that code and database
belong together, restore the matching code if needed, or use the explicit
maintenance Job after a backup. Never force a downgrade by editing a database
version value.

## Browser gets PHP source

This is a failed deployment, regardless of HTTP 200. The Apache PHP handler must
be active. Restore the chart-managed Apache configuration and run
`/opt/helmforge/smoke.php`; health bodies must be exactly `ok` and `ready`, and
the login response must be HTML. Do not expose a server serving PHP source.

## Redirect goes to localhost

The default URL is for local port forwarding. Set `moodle.wwwroot` to the actual
public root URL, without a trailing slash, and configure the matching Ingress
or HTTPRoute hostname.

## Reverse proxy abuse or redirect loop

For a host-preserving controller, use `reverseProxy=false`. Set `sslProxy=true`
when TLS terminates at a trusted proxy and keep `wwwroot` HTTPS. Verify that
backend access and forwarded headers cannot be spoofed by untrusted clients.

## Uploads fail with HTTP 413

Align gateway/Ingress body size, `php.uploadMaxFilesize` and `php.postMaxSize`.
Check Moodle's own course/site upload restrictions. PHP settings cannot override
a smaller limit enforced by the gateway.

## Moodledata is not writable

Check the PVC's ownership, storage-driver fsGroup support and volume capacity.
The workload uses UID/GID 33 and fsGroup 33. Imported NFS data may need an
administrator to set ownership/permissions before installation.

Do not solve permission failures by making application code writable or running
all workloads as root. Keep the distinction between code and mutable data.

## Cron is stale

Inspect the `cron` container, task administration pages and `checks.php`.
Verify cron has not been disabled for maintenance. Long-running tasks, SMTP
timeouts and unreachable integrations can delay later work.

```bash
kubectl -n learning logs deployment/moodle -c cron --tail=100
kubectl -n learning exec deployment/moodle -c moodle -- \
  php /var/www/html/admin/cli/checks.php
```

## Users lose sessions after scaling

Verify Redis credentials, key prefix, TLS, availability and eviction policy.
Use dedicated session storage and make sure all replicas use the same settings.
Do not confuse Redis sessions with MUC cache mappings.

## New replicas remain Pending

Check capacity, anti-affinity, topology spread and storage access modes. Multiple
nodes require actual RWX storage. The chart blocks obvious incompatible values;
it cannot turn a storage backend into a multi-writer filesystem.

## Maintenance Job cannot be updated

Kubernetes Jobs have immutable pod templates. Give each deliberate operation a
new `maintenance.runId`. Inspect previous logs before retrying a failed upgrade.
An operation with the same ID is not a new execution.

## Maintenance Job fails or times out

Inspect its `prepare-code` and `maintenance` logs and the namespace events.
Check task drain, database connectivity, PVC mounts and the intended source
version. Maintenance remains enabled after an upgrade by design.

Do not disable maintenance until migration and application checks are complete.
Use the documented restore procedure if the database cannot safely advance.

## ExternalSecret does not become Ready

Inspect the ExternalSecret conditions, SecretStore and remote property names.
Confirm the generated target name matches the workload's `existingSecret`.
The operator must serve `external-secrets.io/v1`.

## A changed password does not take effect

Administrator bootstrap settings only apply to first installation. Existing
database and Redis passwords must be changed in their services as well as their
Secrets. Restart PHP pods after updating environment-based connection secrets.

## HTTP checks pass but a course feature fails

Health probes do not exercise every plugin, external identity provider or course
format. Validate representative learning workflows, submissions and downloads
with the actual production plugins and integration configuration.
