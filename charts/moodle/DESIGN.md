# Moodle chart design

## Architecture

The chart separates official PHP/Apache runtime, immutable Moodle code and
persistent Moodledata. The default PostgreSQL dependency creates the database;
a serialized init container invokes Moodle's own installer. Web, cron and
optional ad-hoc workers share the pod's code/data but have independent resource
limits and local temporary directories.

## Production choices

- Both runtime and code are content-pinned. Archive mode is reproducible but
  depends on HTTPS availability during pod creation. Image mode supports offline
  deployments and reviewed plugins.
- Apache runs as UID 33 on port 8080 with no added capabilities, no privilege
  escalation and read-only root/code. Its PHP handler is explicit and tested.
- The public document root excludes config.php and CLI scripts.
- PostgreSQL, MySQL and MariaDB use native Moodle drivers. Explicit selection
  validates the matching HelmForge dependency or external connection. PostgreSQL
  remains the default; selecting another engine does not convert existing data.
- Installation uses connection-scoped PostgreSQL or MySQL/MariaDB advisory locks; normal startup rejects database
  version mismatch. An explicit maintenance Job handles schema changes.
- Cron shares the web pod so the default RWO data volume is safe. Moodle's
  database locks coordinate parallel cron processes across replicas.
- Redis sessions are optional and separate from administrator-managed MUC caches.
- Optional tool_monitoring code is pinned and checksum-verified. Its bearer token
  is Secret-mounted and its endpoint is confined to a private Apache listener.
  ServiceMonitor discovery and PrometheusRule evaluation use Prometheus Operator.
- Monitoring plugin schema changes follow the same explicit maintenance lifecycle
  as Moodle core. Replicated exporters report global counts, requiring replica
  deduplication before aggregation.
- Multiple replicas/HPA require shared writable data and Redis sessions.
- Database backups alone are not full-site backups. The chart provides a
  coordinated backup/restore runbook and does not advertise automated site backup.

## Lifecycle limitations

Maintenance requires drained requests/tasks and a recovery point. The chart
cannot infer whether a backup is recoverable. A maintenance Job cannot reverse
schema changes; failed upgrades stay in maintenance for inspection.

Kubernetes replacement can interrupt tasks. Operators should drain cron before
planned upgrades, and validate retries/idempotency of custom tasks. The default
termination grace is not a promise to finish an arbitrarily long course backup.

## Validation boundaries

The lab verifies installed Moodle behavior, PHP execution, login rendering,
cron work, persistent data, secrets, shared-volume concurrency and Kubernetes
manifests. Production storage failover, managed database failover, SMTP delivery,
institutional SSO and third-party plugins require environment-specific tests.
See [validation evidence](docs/validation.md) for executed scenarios and limits.

## Research

See [production research](docs/research.md) for verified upstream sources,
artifact digests and the comparison rationale.
