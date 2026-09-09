# Moodle production research

Research date: 2026-09-09.

## Verified upstream

- [Moodle downloads](https://download.moodle.org/releases/latest/): release 5.2.2.
- [Moodle PHP Apache](https://github.com/moodlehq/moodle-php-apache): PHP runtime,
  not a packaged Moodle application. The image targets development; the chart
  supplies an explicit production Apache/PHP configuration and bypasses its
  configuration-mutating entrypoint.
- [moodle-docker](https://github.com/moodlehq/moodle-docker): development and test
  composition, not a production deployment reference to copy unchanged.
- [Requirements](https://moodledev.io/general/releases/5.2): PHP 8.3+, PostgreSQL
  16+, sodium and at least 5000 input variables.
- [Server clusters](https://docs.moodle.org/501/en/Server_cluster): moodledata,
  cache, temp and backup temp remain shared; only local caches are node-local.
- [CLI](https://docs.moodle.org/502/en/Administration_via_command_line): use
  install_database.php when config.php already exists; cron runs every minute.
- [Upgrading](https://docs.moodle.org/502/en/Upgrading): maintenance and backups
  precede schema migration; Helm rollback cannot undo database migration.

The downloaded release was inspected directly: CLI scripts remain in admin/cli;
public/version.php contains 5.2.2 and database version 2026042002.00. Apache must
serve public/ with FallbackResource /r.php, while config.php stays outside it.

## Reproducible inputs

- Runtime: docker.io/moodlehq/moodle-php-apache:8.4-bookworm, manifest index
  sha256:922af51668352004b4255cdc1f726a63f0cee7c1354eaf66dd8d5f2c7cc379b5.
  Verified linux/amd64 and linux/arm64 manifests; PHP reports 8.4.25.
- Application: <https://download.moodle.org/download.php/direct/stable502/moodle-5.2.2.tgz>
- Package SHA-256: 72be209e7c0f5341b87de0bc993b2430087fda2769d8c3cc2f32736d1513e88c.
  Compared downloaded bytes with the official checksum endpoint.

## Comparison

| Concern | Bitnami container/chart | HelmForge implementation direction |
| --- | --- | --- |
| Application distribution | Application bundled with vendor scripts | Official package checksum plus official runtime digest; offline image option |
| Installation | Vendor environment-variable bootstrap | Explicit config.php and upstream CLI with database serialization |
| Persistence | Application and moodledata persistence | Immutable code separated from persistent user data |
| Scheduling | Vendor cron integration | Supervised CLI workload with its own resources and graceful shutdown |
| Scale | Requires shared storage | Reject unsafe scale; shared data plus explicit Redis sessions |
| Secrets | Existing secrets | Existing secrets plus canonical External Secrets items contract |
| Routing | Ingress | Ingress and Gateway API with explicit public URL/proxy contract |
| Upgrades | Vendor startup scripts | Explicit maintenance workflow; reject implicit database upgrades |

Comparison reference: [Bitnami README](https://github.com/bitnami/containers/blob/main/bitnami/moodle/README.md).
Bitnami variable names are not an upstream Moodle API. No Bitnami image or script
is used. No official MoodleHQ Helm chart was identified in the research.

## High-impact differentiators

1. Reproducible code and runtime with a read-only application filesystem.
2. Serialized installation and explicit schema lifecycle, protecting existing data.
3. Render-time HA safety checks plus operational cron, secrets and proxy contracts.

Redis session storage is distinct from MUC cache mapping. Core database advisory locks
coordinate tasks; the chart must not invent a Redis lock factory. Reverseproxy
defaults false because ordinary host-preserving Ingress does not require it.

## Prometheus integration

The selected integration is
[tool_monitoring](https://github.com/daniil-berg/moodle-tool_monitoring), release
1.1.0, pinned to commit `23c45f66b6c3ed409b0749017b3387c1744016cc`.
Its Moodle-native metrics manager supports PostgreSQL, MySQL and MariaDB through Moodle's native database API
and its Prometheus exporter supports bearer authentication. The chart isolates
the endpoint on a dedicated listener and supplies a ServiceMonitor and optional
PrometheusRule. See [observability](observability.md) for the lifecycle contract.

[SysBind moodle_exporter](https://github.com/SysBind/moodle_exporter) was also
evaluated; its database discovery and fixed PostgreSQL port/table-prefix
assumptions do not match this chart's configurable connection contract.
[ATComputing moodledb-exporter](https://github.com/atcomputing/moodledb-exporter)
targets MySQL. The selected Moodle-native plugin covers all three supported
backends without a separate SQL exporter. Neither alternative is bundled.

## Artifact and infrastructure risks

Archive preparation requires HTTPS egress and adds startup latency. An immutable
operator-built image is needed for offline operation or additional plugins.
Shared storage availability and database durability determine service availability;
multiple web replicas alone are not a complete HA infrastructure. Backup must
cover the database, moodledata and exact code/configuration together.

## Database selection follow-up

The [Moodle database documentation](https://docs.moodle.org/502/en/Database)
lists PostgreSQL, MySQL and MariaDB. Each is now selectable as an external
service or its matching HelmForge dependency. Native Moodle 5.2.2 drivers and
lock factories define the connection, collation and TLS behavior. Runtime
validation exercises each engine, including external verified TLS.
