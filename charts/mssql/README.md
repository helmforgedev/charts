# Microsoft SQL Server

Run Microsoft's official Linux SQL Server image as a persistent, encrypted single
instance. The chart separates engine version from edition, requires explicit EULA
acceptance, provisions declared application databases and supplies native backups
uploaded to S3 without excluding Express users.

## Features

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

## Architecture

The chart deploys one SQL Server StatefulSet behind a TCP Service. By default, a
retained data PVC stores system and user databases. When `persistence.enabled` is
false, the chart uses ephemeral `emptyDir` storage that does not retain databases
across Pod recreation or rescheduling. Optional backup and metrics workloads use
dedicated identities, selectors and least-privilege SQL logins. See [DESIGN.md](DESIGN.md)
for the topology, trust boundaries and intentional gaps.

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

## Configuration

The complete contract is documented in [values.yaml](values.yaml), with field-level
validation in [values.schema.json](values.schema.json) and cross-field guardrails in
the chart templates. These settings define the most common installation choices:

| Value | Default | Purpose |
|---|---|---|
| `license.acceptEULA` | `false` | Explicitly accept Microsoft's EULA and render SQL resources |
| `sql.edition` | `Express` | Select the licensed SQL Server edition independently of the image |
| `sql.memoryLimitMB` | `3072` | Cap native SQL Server memory while leaving container headroom |
| `auth.existingSecret` | `""` | Reuse credentials instead of generating retained passwords |
| `tls.existingSecret` | `""` | Reuse a TLS Secret instead of generating retained certificates |
| `persistence.enabled` | `true` | Persist system and user databases |
| `persistence.size` | `20Gi` | Set the generated data PVC capacity |
| `persistence.retain` | `true` | Retain generated data and recovery material on uninstall |
| `service.type` | `ClusterIP` | Select SQL TCP Service exposure |
| `service.port` | `1433` | Set the client-facing SQL Service port |
| `networkPolicy.enabled` | `true` | Restrict SQL, monitoring and backup network paths |
| `backup.enabled` | `false` | Enable native full backup and S3 upload |
| `metrics.enabled` | `false` | Enable the authenticated SQL exporter |
| `externalSecrets.enabled` | `false` | Render ExternalSecret resources for supplied item definitions |

Schema validation rejects invalid field types, enums, patterns and identifiers.
Chart guardrails reject incompatible editions, insufficient memory headroom and
incomplete backup, metrics or External Secrets contracts before resources reach
the cluster.

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
databases, logs and the SQL encryption hierarchy. When `persistence.enabled` and
`persistence.retain` are true, Helm keeps the generated data PVC and the generated
authentication and TLS Secrets on uninstall. Reinstallation can then recover the
persisted SQL logins with their matching credentials and trust material. Keep the
same release identity, or explicitly reference retained resources through
`persistence.existingClaim`, `auth.existingSecret` and `tls.existingSecret`.

Retained Secrets remain sensitive resources under your management after uninstall.
Protect and back them up with the recovery configuration; delete them deliberately
only when the corresponding retained database is retired or its credentials and
trust have been migrated. Existing Secrets remain owned by their external manager;
ESO installations need stable provider values and appropriate target-Secret
lifecycle settings. Retention does not copy externally managed credentials.
Do not initialize a second SQL writer against the same data claim.
`persistence.enabled: false` is a disposable test mode and does not retain generated
authentication or TLS Secrets through this setting.

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
Successful runs and graceful failures remove only their own local archive files,
so repeated upload failures do not accumulate full database backups in staging.
A bounded `/backup/.last-failure` JSON record preserves failure diagnostics.
Abrupt SIGKILL or node loss can leave orphaned files; inspect and remove those
specific files manually after confirming no active run owns them. No S3 object is
deleted by the chart; bucket lifecycle rules handle incomplete remote prefixes.

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

## Examples

- [Simple Express deployment](examples/simple.yaml)
- [SQL Server 2022](examples/2022.yaml)
- [Developer edition](examples/developer.yaml)
- [Staging](examples/staging.yaml)
- [Production](examples/production.yaml)
- [S3 backup](examples/backup-s3.yaml)
- [Prometheus metrics](examples/metrics.yaml)
- [External Secrets](examples/external-secrets.yaml)

## Troubleshooting

If only the consent ConfigMap is rendered, set `license.acceptEULA=true` after
reviewing Microsoft's license. For a Pod that never becomes Ready, inspect the
bootstrap container logs and confirm that retained SQL credentials still match
the persisted `master` database:

```sh
kubectl logs statefulset/<statefulset-name> -n <namespace> -c mssql
kubectl describe pod -n <namespace> -l 'app.kubernetes.io/instance=<release>,app.kubernetes.io/component=server'
```

For TLS failures, verify that clients trust `ca.crt` and connect through a DNS name
present in the server certificate. For backup failures, inspect the CronJob, its
latest Job and `/backup/.last-failure` before removing any orphaned staging files.
The detailed recovery and credential procedures are in [operations](docs/operations.md)
and [backup and restore](docs/backup.md).

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
