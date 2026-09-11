# SQL Server deployment design

## A licensed database with an explicit startup boundary

Version and edition are independent. The official MCR tag/digest selects engine
bits; `MSSQL_PID` selects the edition, with a documented Developer alias across
2022 and 2025. Edition restrictions are enforced before resources are installed.
No SQL resources are rendered before EULA opt-in. The consent-only default is
tested first, followed by an explicit opt-in and real native database acceptance.

## Stateful single writer

A singleton StatefulSet preserves hostname and storage identity. RollingUpdate
replaces the only Pod, so upgrades intentionally include downtime. This is not
horizontal scaling or Always On. Separate retained data and backup claims keep
system database/encryption state distinct from transient backup staging. A backup
worker uses required same-node affinity to permit RWO mounts; RWOP staging is not
supported because the SQL Pod and backup Job must both access it.

## Startup, secrets and SQL provisioning

A small Python supervisor runs the official Microsoft entrypoint, retaining its
permission checks and edition mapping. It waits for native authenticated SQL,
creates only missing declared databases/logins, grants explicit roles and applies
immutable initialization scripts with a durable transaction ledger. Readiness
appears only after provisioning. Shutdown forwards SIGTERM to the process group.

Strong generated passwords are preserved via live Helm lookup; existing Secrets
avoid render-only drift. Persisted SQL credentials are authoritative: a changed
Secret cannot silently rewrite master or application logins. The administrator is
used for provisioning; readiness, metrics and backup have separate logins.
Liveness is a TCP check so a readiness credential error is not directly converted
into a process restart.

## Encrypted transport

SQL Server requires TLS. A generated private CA and certificate are retained, or
an existing Secret supplies the trust material. An unprivileged init container
copies key/certificate to an in-memory volume with mode 0600. Private keys are
not mounted in exporter or backup Pods. Local probes intentionally trust only
loopback; remote SQL clients verify certificate chain and DNS identity.

## Native backup plus portable object upload

Native SQL S3 backup excludes Express. A uniform disk-to-S3 path uses native
COPY_ONLY/CHECKSUM backup in the server, then AWS CLI upload with per-file SHA-256
and a completion manifest published last. Scheduling uses Kubernetes rather than
SQL Agent. Failed runs retain local artifacts; successful runs delete only their
own files. Retention stays with explicit bucket lifecycle policy. There is no
log-backup/PITR claim or automatic overwrite restore path.

## Operational separation

SQL, backup and metrics Pods have distinct component selectors. Only the SQL Pod
backs the database Service. NetworkPolicies separately control client admission,
monitoring access and object-storage egress. A projected AWS identity token is an
explicit backup-only option, never a general API credential on the database Pod.
Metrics require native SQL query success and cannot substitute for object-storage
backup completion evidence.

## Restricted execution and the official binary capability

The database runs as non-root with a read-only root filesystem, disabled privilege
escalation and a RuntimeDefault seccomp profile. Every container drops all Linux
capabilities. The SQL Server container adds only NET_BIND_SERVICE because the
official sqlservr executable carries that file capability; excluding it from the
bounding set prevents execution with EPERM even though the SQL listener uses
port 1433. This requirement was verified with the pinned image in k3d. Init,
exporter and backup containers retain an empty capability set. SYS_PTRACE is not
enabled; crash-dump collection requiring it is outside the default security
profile.
