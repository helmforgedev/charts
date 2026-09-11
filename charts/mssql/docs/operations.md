# Production operations

## Deployment contract

This chart runs one SQL Server instance in a StatefulSet. Pod replacement recovers that instance from its persistent storage and causes an
interruption while SQL Server starts and recovers databases. Additional replicas, automatic failover, Always On availability groups, and horizontal
autoscaling are outside this chart's contract.

Choose the engine release and edition deliberately; see [editions](editions.md). SQL Server workloads are gated by `license.acceptEULA`. Use an
appropriately licensed edition for production, reserve suitable CPU and memory, and verify storage latency and throughput with the application's
workload before admitting traffic.

For predictable production scheduling, set equal CPU and memory requests and limits for every container so the Pod has Guaranteed QoS. Leave headroom
between SQL Server's configured memory budget and the container memory limit. A small example configuration is not a capacity guarantee for arbitrary
databases or concurrency.

The official SQL Server executable has a NET_BIND_SERVICE file capability. The SQL container drops all capabilities and adds only
NET_BIND_SERVICE to permit that executable to start; other containers drop all capabilities. Non-root execution, a read-only root filesystem,
disabled privilege escalation and RuntimeDefault seccomp remain enforced. SYS_PTRACE is not enabled for crash-dump collection by default.

## Credentials and bootstrap

`auth.existingSecret` can supply `sa-password`, `probe-password`, `metrics-password`, and `backup-password`. Generated credentials are independent and
retained during live Helm upgrades through Secret lookup. Use stable externally managed Secrets for GitOps workflows that only render templates and
cannot look up the live Secret.

The `sa` account is for administration. Readiness, monitoring, and backup use their separate accounts; applications should use their own logins. TCP
liveness checks avoid restarting an otherwise running engine because a login password is temporarily inconsistent. A failed SQL readiness check
requires investigation of startup, recovery, or credentials.

Use `initdb.databases` to declare initial databases by `name`. Optional application logins use `username`, `existingSecret`, and `passwordKey`;
`recoveryModel` defaults to `SIMPLE`. The bootstrap creates missing databases and logins. It does not provide application schema migrations or
automatically replace passwords of existing logins. Maintain migrations in the application or a separately controlled deployment process.

Application roles default to db_datareader, db_datawriter and db_ddladmin; override the entry's `roles` when the application does not need schema
changes. These roles apply inside its declared database, not at server scope. Initial recovery models are applied only when the database is created.

`initdb.scriptsConfigMaps` mounts reviewed SQL scripts for transactional one-time application. Each script is tracked by ConfigMap name, filename,
SHA-256 and application time in the master database ledger. Keep each script compatible with an explicit transaction; operations that cannot run
inside a transaction belong in a separate controlled procedure. GO-separated batches are supported. A changed previously applied script fails
bootstrap; use a new filename for a deliberate follow-up. Do not edit ledger entries to force an automatic rerun.

Updating a Kubernetes Secret does not execute `ALTER LOGIN` against an existing SQL Server data directory. Coordinate credential rotation explicitly:

1. Retain a working administrative session and confirm a recent recoverable backup.
2. Generate the replacement credential through the approved secret-management process.
3. Change the corresponding SQL login with `ALTER LOGIN` over a trusted encrypted connection. Avoid recording the password in shell arguments or query logs.
4. Update the matching Secret and restart the client workloads that consume it as environment variables.
5. Verify new connections for applications, probes, monitoring, and backups as applicable before retiring the old credential.

For the administrative account, rotate the SQL login and its Secret as one maintenance operation. Preserve required operational login credentials when
attaching an existing claim. A new random Secret cannot authenticate to logins that were initialized with a different password on the retained volume.

## TLS and network access

The generated default certificate material includes a retained self-signed CA. It provides encrypted transport, but production deployments should
supply their approved certificate lifecycle through `tls.existingSecret`. That Secret includes `tls.crt`, `tls.key`, and `ca.crt`. Certificates must
cover the DNS name used by SQL clients and permit server authentication.

Distribute the trusted CA to clients and validate the server identity. Do not normalize `TrustServerCertificate=true` as the production connection
setting. Existing Secrets are mounted for the non-root process; verify file ownership and permissions on the chosen storage driver.

Restrict database traffic to the actual application namespaces and Pods. Restrict exporter traffic to the actual monitoring peers. NetworkPolicy
enforcement depends on the cluster CNI. A rendered policy or ServiceMonitor is not proof that traffic is isolated or metrics are scraped; validate
allowed and denied connections in the target environment.

Plan certificate renewal with a SQL Server restart and validate the presented certificate after the rollout. Back up the required trust material
separately from database backups. Do not expose SQL Server through an HTTP Ingress; use a controlled TCP connection path and a correctly named
certificate.

## Persistent storage

Persistence is enabled by default. Use `persistence.existingClaim` when storage is managed independently. Retain storage across uninstall or
replacement according to the chart and StorageClass reclaim policies, and verify the actual claim/PV behavior before production use.

SQL Server needs a writable data directory for system databases, user databases, transaction logs, and security material. Restrict access to the
volume, especially `/var/opt/mssql/secrets`. Do not mount a single SQL Server data directory into multiple active instances. Claims restored from
another installation must have compatible engine version, ownership, and credentials.

Monitor free capacity and growth. Filling the data volume or backup staging area can interrupt writes and backups. PVC snapshots alone do not
demonstrate a consistent, restorable database backup. Test the selected backup and restore process against real data.

## Backup and recovery

Scheduled backups use a Kubernetes CronJob and native full `COPY_ONLY` backup files followed by S3 upload. This design also supports Express, which
does not provide SQL Server Agent or the native S3 connector. Upload completion, object retention, credentials, endpoint trust, and recovery must be
verified together.

Treat S3 lifecycle rules, immutability, encryption, and access policies as part of the operational backup configuration. Keep database backups outside
the SQL Server data volume's failure domain. Restrict backup object access: an unencrypted native backup can disclose database contents to anyone able
to retrieve and restore it.

Full copy-only backups do not create a managed transaction-log backup chain and do not promise point-in-time recovery. Choosing `FULL` recovery for a
database requires a separately operated log backup strategy; otherwise its transaction log can continue growing. Do not select FULL solely because the
chart has a full backup CronJob.

Run a restore drill into an isolated instance with a compatible engine version. Restore the database, check integrity, query known application
records, and reconnect the application with the intended login. A successful upload or `RESTORE VERIFYONLY` alone is not equivalent to a successful
restore drill. Database backups do not automatically recreate every server-level login, job, credential, certificate, or configuration; preserve those
through a protected, tested recovery process.

Record recovery duration and the newest recoverable backup timestamp. Those measurements establish achievable recovery objectives for the environment.

## Upgrade and rollback

Review upstream release notes, image digest, edition compatibility, and database feature usage before an upgrade. Restore a recent production backup
into a test instance with the proposed image and run application acceptance tests. Schedule the interruption and confirm sufficient recovery time.

After rollout, check the actual engine and edition, database states, readiness, application reads and writes, metrics, and the next backup. Verify
that credentials and data survived Pod replacement.

Helm rollback restores Kubernetes configuration; it does not downgrade SQL Server database files or reverse migrations. If a database has been
upgraded beyond the older engine's compatibility, restore the appropriate pre-upgrade backup into a separately prepared compatible instance and follow
the tested recovery procedure.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| No SQL Server workload after installation | Confirm explicit `license.acceptEULA: true`. |
| Pod remains Pending | Inspect amd64 node selection, reserved resources, PVC binding, and topology constraints. |
| SQL Server cannot write its data directory | Check non-root UID/group access and the storage driver's fsGroup behavior. |
| Login fails after Secret update or claim reuse | Compare the existing SQL login credential with the Secret; coordinate `ALTER LOGIN` instead of regenerating credentials. |
| Readiness fails while TCP remains open | Inspect database recovery and the dedicated probe login before restarting SQL Server. |
| Client rejects the certificate | Check CA trust, certificate validity, and the DNS name used by the connection. |
| OOMKilled | Check SQL Server's memory budget, container headroom, workload concurrency, and the supported cgroup version. |
| SQL Agent cannot start | Verify the edition; Express does not include SQL Server Agent. |
| S3 backup fails | Check native backup completion, staging capacity, uploader logs, endpoint/CA, credentials, and object-store permissions. |
| Prometheus target is missing | Check installed Operator CRDs, namespace/label selection, Service endpoints, and monitoring network peers. |
| Transaction log grows after enabling FULL recovery | Operate a log backup strategy or use the recovery model appropriate to the documented full-backup-only contract. |
| Old image cannot start after an engine upgrade | Use the tested restore procedure; image rollback does not downgrade database files. |
