# Moodle validation evidence

Validated on 2026-09-09 against Moodle 5.2.2 and the pinned MoodleHQ PHP 8.4
runtime. Kubernetes context: `k3d-helmforge-tests-wsl`, Kubernetes 1.31.5.

## Complete database-options gate

```bash
make validate-chart CHART=moodle TIMEOUT=900
```

The validation workstream passed dependency resolution and bundle integrity,
strict lint, every CI render, 76 unit tests in 14 suites, strict kubeconform with
real CRD schemas, Artifact Hub lint and all 12 behavioral scenarios. All
deployment examples also rendered successfully.

The all-scenario run exposed a MariaDB/application resource-name collision.
The final chart rejects such collisions, and the bundled CI cases use distinct
database names. The final gate repeated every static layer, the default install
and all five remaining scenarios. Six unchanged scenarios retain their passing
evidence from the preceding run. The command above reproduces the complete
matrix; the final executed gate selected these runtime cases:

Its runtime selection was `default`, `ci/mariadb-values.yaml`,
`ci/metrics-values.yaml`, `ci/mysql-values.yaml`, `ci/redis-worker-values.yaml`
and `ci/shared-storage-values.yaml`.

Result: FULLY VALIDATED. The scenarios below are the union of the successful
runs against the final database implementation and the corrected name contract.

| Runtime scenario | Result | Application evidence |
| --- | --- | --- |
| Default PostgreSQL | PASS | Native driver, installation, administrator login and cron |
| Dual-stack values | PASS | Service policy, installed application and login |
| External PostgreSQL | PASS | Installation and login with verify-full TLS and mounted CA |
| External MariaDB | PASS | Native driver, verified TLS, custom port, Secrets and real Prometheus collection |
| External MySQL | PASS | Native driver, verified TLS, custom port, Secrets and real Prometheus collection |
| External Secrets | PASS | SecretSynced/Ready and login with synchronized credentials |
| Ingress/Gateway API | PASS | Accepted resources and application checks through the Service |
| Bundled MariaDB | PASS | HelmForge subchart, non-default table prefix, login, cron and authenticated metrics |
| Prometheus monitoring | PASS | PostgreSQL-backed application, discovery, course-count changes and rule evaluation |
| Bundled MySQL | PASS | HelmForge subchart, non-default table prefix, login, cron and authenticated metrics |
| Redis and worker | PASS | Redis-backed login, cron, ad-hoc container and NetworkPolicy |
| Shared storage | PASS | Two replicas, serialized bootstrap, login, cron and shared file marker |

The server versions exercised were PostgreSQL 18.6, MySQL 9.7.2 and MariaDB
12.3.3. Minimum supported versions are taken from Moodle's upstream requirements;
this matrix does not test every server version between those minimums and the
pinned versions.

Every application scenario checked exact health bodies, rendered login HTML,
authenticated administrator access, private configuration paths and read-only
code. Two independent database connections verified lifecycle-lock exclusion
and release after closing the lock holder. Successful scenarios had no container
restarts or crash terminations. Transient database startup probe warnings were
accepted only after the workloads became healthy. Lab namespaces were cleaned.

## TLS and Prometheus

External MySQL and MariaDB used port 3307, a custom password Secret key and a
private test CA. Both the bootstrap connection and native Moodle driver rejected
a resolvable hostname absent from the certificate. The native driver also
rejected an untrusted CA. Its separate require mode established an encrypted
connection without requiring a matching certificate hostname.

Prometheus Operator 0.94.0 and digest-pinned Prometheus 3.14.0 exercised
ServiceMonitor and PrometheusRule resources with tool_monitoring 1.1.0:

- Missing/invalid bearer credentials returned 403; valid credentials returned 200.
- All five configured metric families appeared.
- The public listener rejected metrics and the private listener rejected login pages.
- Prometheus discovered the target and reported up=1.
- Creating a temporary Moodle course increased the collected count; cleanup restored it.
- Rules loaded and evaluated with healthy status.

Real collection ran against PostgreSQL, MySQL and MariaDB. Alertmanager
notification delivery was not exercised.

## Maintenance and recovery checks

The external MySQL installation completed a same-version maintenance upgrade
Job, explicit disable Job and web-pod replacement. Administrator login, cron,
verified TLS and real Prometheus collection passed after service resumed.
MariaDB additionally exercised the maintenance adapter's purge-caches command.

MySQL and MariaDB native dumps were restored into separate empty databases.
Each restored database contained the two initial users and one site course;
dump SHA-256 hashes were recorded. These checks verify native dump/restore
artifacts and basic contents, not a complete production recovery or an RTO/RPO.

The initial chart validation also verified PostgreSQL pg_dump/pg_restore,
Moodledata archive extraction and a data marker surviving pod replacement.
The filesystem recovery procedure is unchanged. Database engine conversion
and version-to-version Moodle schema migration are not performed by this chart.

## Security and site

Kubescape 4.0.13 scored the default render at 93.63636% using MITRE, NSA and
SOC2 policies. Findings include opt-in NetworkPolicy and the database's writable
filesystem. The scanner also classified the existing metrics test's literal
Bearer authorization header as a misplaced secret; its actual token is loaded
from a Kubernetes Secret. This is a Kubernetes configuration assessment, not an
image vulnerability scan.

The synchronized site passed lint, formatting, build and local-link checks with
Node 24.21.0. Browser checks covered database/subchart selection, external
connection parameters and generated deployment output. Cross-repository catalog
parity remains 97 charts.

## Validation boundaries

- Shared-volume concurrency uses the single-node lab; production RWX failover,
  database replication/failover, HPA load and capacity need infrastructure tests.
- Ingress and HTTPRoute resources use real schemas, but no production gateway
  traffic path or production certificate is certified.
- Dual-stack values do not certify IPv6 connectivity.
- SMTP, SSO, custom plugins and custom offline images need environment-specific tests.
- Full-site backup requires the coordinated [recovery procedure](backup-restore.md).
