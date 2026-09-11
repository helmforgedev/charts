# Monitoring

The optional metrics Deployment uses the original maintainer's
[SQL Exporter](https://github.com/burningalchemist/sql_exporter), a pinned image,
and a dedicated SQL login `hf_metrics`. It runs as UID/GID 65534 with a read-only
root filesystem and no Kubernetes API token. It exposes a private ClusterIP
Service on port 9399. Enable the ServiceMonitor and PrometheusRule only when
the Prometheus Operator CRDs are installed and their labels match your
Prometheus selectors. See [the metrics example](../examples/metrics.yaml).

Allow your Prometheus namespace and Pod labels through `metrics.ingressFrom`.
An empty peer list grants no external access under the chart NetworkPolicy.
The exporter connects to SQL Server over certificate-validated TLS. Only the
CA certificate is mounted into the exporter; the server private key is not.
Its DSN comes from the `<fullname>-metrics` Secret key `dsn`, never from command
arguments. Set `metrics.existingSecret` and `metrics.secretKey` (default `dsn`)
when supplying an external DSN; this is required with an external authentication
Secret because Helm cannot safely derive an unavailable password. Its
`hf_metrics` password must match the authentication Secret's `metrics-password`.
A custom SQL Server certificate must include the SQL Service name
in its SANs, and its Secret must supply `ca.crt`. The exporter projects that key
as `/tls/ca.pem`: its Go SQL driver selects certificate format by extension
and accepts `.pem` or `.der`, not `.crt`. External DSNs must use
`encrypt=true&TrustServerCertificate=false&certificate=/tls/ca.pem`.
The SQL Server and backup certificate paths remain unchanged.
Rotate the SQL monitoring
password and its DSN together, then restart the metrics Deployment to refresh
the environment. Merely changing a Kubernetes Secret does not change a login
stored in SQL Server.

The included collector exposes:

| Metric | Meaning |
| --- | --- |
| `mssql_instance_ready` | Successful authenticated query, value 1 |
| `mssql_user_connections` | Current user sessions, including monitoring |
| `mssql_database_state` | Visible user-database state; 0 means ONLINE |
| `mssql_database_allocated_bytes` | Allocated data/log bytes, not filesystem free space |
| `mssql_io_stall_seconds_total` | Cumulative I/O stall; use `rate()` for change over time |

The monitoring login needs `CONNECT SQL`, metadata visibility through
`VIEW ANY DEFINITION`, and `VIEW SERVER PERFORMANCE STATE` on SQL Server
2022 and newer. It does not need `sysadmin`. Database-state results are limited
to metadata visible to this login; do not treat this exporter as a complete
inventory of deliberately hidden or inaccessible databases.

`MSSQLMetricsUnavailable` fires after five minutes when the scrape fails or
the target disappears. SQL authentication or collector errors can fail the
scrape even when the exporter process is running. `MSSQLDatabaseNotOnline`
flags a visible user database remaining outside ONLINE for five minutes;
planned restores can legitimately trigger it. Exporter probes check its TCP
listener so a database failure does not cause a metrics-container restart loop.

This collector does not fabricate backup-success metrics. A successful SQL
backup history entry does not prove successful S3 upload. Monitor the backup
CronJob's completed Jobs and remote objects; kube-state-metrics is required
for Kubernetes Job/CronJob alerts. A production overdue-backup rule must also
handle a schedule that has never succeeded. PVC capacity alerts require
kubelet volume metrics and suitable thresholds for your storage system.

The upstream driver documents the distinction between certificate validation
and insecure trust bypass in its
[TLS connection parameters](https://github.com/microsoft/go-mssqldb#connection-parameters-and-dsn).
