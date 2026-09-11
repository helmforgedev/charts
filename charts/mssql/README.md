# Microsoft SQL Server

Run Microsoft's official Linux SQL Server image as a persistent, encrypted single
instance. The chart separates engine version from edition, requires explicit EULA
acceptance, provisions declared application databases and supplies native backups
uploaded to S3 without excluding Express users.

## Production contract

- One StatefulSet Pod and one database writer, including system databases and keys.
- Official MCR image pinned by release and digest, Linux amd64 only.
- Express by default; Developer variants and licensed editions explicitly selectable.
- TLS encryption enforced, with retained generated CA/certificate or an existing TLS Secret.
- Native SQL authentication, retained generated credentials or existing/ESO Secrets.
- Non-root UID/GID 10001, read-only image, only NET_BIND_SERVICE capability, no API token.
- Authenticated readiness and independent TCP liveness; explicit SQL network peers.
- Native full COPY_ONLY backups, CHECKSUM, SHA-256 manifest and HTTPS S3 upload.
- Optional original-maintainer SQL exporter, ServiceMonitor and PrometheusRule.

This is a singleton deployment. Pod recovery and StatefulSet upgrades involve
downtime. It does not configure Always On, replication, automatic database failover,
horizontal autoscaling, log backups or point-in-time recovery.

## Install and select an edition

Read [Microsoft's container licensing guidance](https://learn.microsoft.com/en-us/sql/linux/containers/deploy).
Without `license.acceptEULA: true`, the chart creates only a consent ConfigMap:
no SQL process, credentials, Service or PVC. This prevents implicit license acceptance.

```yaml
license:
  acceptEULA: true
sql:
  edition: Express
```

```sh
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm upgrade --install database helmforge/mssql -n database --create-namespace -f values.yaml
```

OCI installation uses `oci://ghcr.io/helmforgedev/helm/mssql`.
`image.tag` selects the SQL Server engine; `sql.edition` selects its licensed feature
set. `Developer` maps to EnterpriseDeveloper on 2025 and Developer on 2022.
Developer/StandardDeveloper/EnterpriseDeveloper are for development and testing.
Express can serve production workloads within its limits. Standard/Enterprise
require appropriate licenses; the chart does not grant one.

See [editions and version compatibility](docs/editions.md), [2022](examples/2022.yaml),
[development](examples/developer.yaml), [staging](examples/staging.yaml) and
[production](examples/production.yaml). Product keys are accepted only through a
Secret reference with `sql.edition: ProductKey`.

## Connect securely

The Service exposes SQL TCP 1433 by default. This is not an HTTP endpoint; HTTP
Ingress and HTTPRoute are deliberately absent. Keep ClusterIP and authorize only
application peers through `networkPolicy.ingressFrom`. External LoadBalancer
exposure requires routing, firewall and certificate planning.

The TLS Secret contains `tls.crt`, `tls.key`, `ca.crt`. With generated certificates,
trust the supplied CA and use the Service DNS name. Add external DNS names through
`tls.extraDnsNames` before the first installation, or supply your own certificate.
Generated certificates are retained on Helm upgrades; editing SANs/duration does
not silently replace an existing certificate. See [operations](docs/operations.md).

Use an application login for normal traffic. To perform administrator operations,
retrieve the `sa-password` entry from the Secret identified in Helm NOTES and pass
it through `SQLCMDPASSWORD` or a secure credential provider, never CLI `-P`.
The chart probes use loopback with explicit certificate trust bypass restricted to
that in-Pod connection; remote backup and monitoring connections verify CA and name.

## Credentials and database initialization

The authentication Secret has four entries: `sa-password`, `probe-password`,
`metrics-password`, `backup-password`. The managed mode generates strong random
values and retains them through live Helm lookup. Existing Secret mode is preferred
for GitOps/render-only controllers. External Secrets uses the canonical `items[]`
contract and the actual `external-secrets.io/v1` CRD.

Changing a Kubernetes Secret does not alter an existing SQL login. The bootstrap
verifies configured credentials and does not silently reset passwords in persisted
`master`. Rotate SQL credentials deliberately, then update the corresponding Secret
and restart dependent clients as described in [operations](docs/operations.md).

```yaml
initdb:
  databases:
    - name: application
      username: application
      existingSecret: application-db
      passwordKey: password
      recoveryModel: SIMPLE
      roles: [db_datareader, db_datawriter, db_ddladmin]
```

Database and login names use a restricted ASCII identifier contract. Existing
databases/logins are preserved. Recovery mode is applied only when creating a new
database. The supplied application password must match a pre-existing login.
Default roles permit common reads/writes/schema migrations, not server administration;
choose narrower roles where applicable. Role changes add grants and do not revoke
earlier grants automatically. Removing a values entry never drops a database/login.

Reviewed `.sql` files may be mounted through `initdb.scriptsConfigMaps`. These are
trusted administrator scripts, executed in a transaction on one sqlcmd connection.
A durable ledger records names and SHA-256 hashes after success. Applied scripts
must be immutable: use a new filename for a new migration. Avoid scripts that manage
their own transactions or require nontransactional SQL operations.

## Storage and memory

The default 20Gi data claim retains `/var/opt/mssql`, including `master`, user
databases, logs and the SQL encryption hierarchy. The generated PVC is retained on
uninstall. Reuse it with `persistence.existingClaim`; do not initialize a second SQL
writer against it. `persistence.enabled: false` is a disposable test mode.

The default Pod requests and limits are both 2 CPU/4Gi. Native server memory is
capped at 3072Mi to leave process overhead. Schema/helper checks reject insufficient
memory headroom. Budget actual workload growth, storage latency and backup staging
separately. Both supported engine pins honor cgroup v2. Microsoft supports Linux
x86-64 container hosts, not ARM emulation.

## S3 backup and recovery

Enable [the backup example](examples/backup-s3.yaml) with explicit databases,
destination bucket, HTTPS endpoint/region and either static AWS credentials or an
explicit AWS web-identity role. The chart does not create buckets or change retention.

The SQL server writes consistent native backups into a dedicated staging PVC.
A scheduled Job is placed on the SQL node so both containers can mount RWO storage.
The SQL client uses a dedicated login with `db_backupoperator` only on selected
databases. The AWS CLI uploads verified files and publishes a manifest last.
A failed upload keeps staging files for diagnosis; successful runs remove only
their own local files. No S3 object is deleted by the chart.

Express/Web reject compression; Express needs neither SQL Agent nor native S3 URL
support for this pipeline. Use S3 encryption/lifecycle controls and a recovery drill
appropriate to your data. Copy-only full backups do not truncate FULL recovery logs
or offer PITR. See [backup, retention, permissions and restore](docs/backup.md).

## Monitoring

The optional [SQL exporter](docs/monitoring.md) has a separate Pod/Service, a dedicated
SQL login and a CA-validated connection. Explicitly authorize Prometheus peers.
The exporter mounts Secret key `ca.crt` as `/tls/ca.pem`; external DSNs must use
`certificate=/tls/ca.pem` with encryption enabled and certificate verification.
The Go SQL driver requires a `.pem` or `.der` filename extension.
With externally managed SQL credentials, provide `metrics.existingSecret` with a
matching DSN instead of requiring Helm to read credentials before ESO synchronizes.

Alerts cover unavailable/missing scrape targets and databases outside ONLINE.
Exporter SQL metrics do not prove a successful S3 upload. Monitor the backup CronJob,
remote completion manifests, staging capacity and `.last-success` as distinct signals.
See [metrics values](examples/metrics.yaml).

## Validation and security scan

Release acceptance requires the complete `make validate-chart CHART=mssql` gate,
real SQL operations, TLS rejection tests, data retention, S3 upload/restore and
Prometheus query checks. Paid editions are contract/render tested unless a licensed
runtime environment is supplied; Developer profiles exercise their engine feature set.

### Security Scan: `mssql`

| Framework | Score |
|---|---|
| MITRE + NSA + SOC2 | **100%** |

Local Kubescape 4.0.13 scan on 2026-09-11, rendered with `examples/production.yaml`
and explicit EULA acceptance. This score covers Kubernetes configuration controls,
not container vulnerability scanning or a database security audit.

Localhost client trust bypass, retained bootstrap administrator access and explicit
workload identity tokens are documented security decisions, not hidden defaults.
The official sqlservr binary carries `cap_net_bind_service=ep`; excluding this
capability from its bounding set prevents execution even on SQL port 1433.
Only the SQL container receives NET_BIND_SERVICE; backup/exporter containers drop all.

## References

- [Microsoft container source](https://github.com/microsoft/mssql-docker)
- [Microsoft StatefulSet practices](https://learn.microsoft.com/en-us/sql/linux/containers/kubernetes-best-practices-statefulsets)
- [SQL Server editions](docs/editions.md)
- [Operations and upgrades](docs/operations.md)
- [Backup and restore](docs/backup.md)
- [Monitoring](docs/monitoring.md)
