# QuestDB chart design

## Workload model

The chart deploys a fixed one-replica StatefulSet. QuestDB OSS is not
horizontally scalable, so replicas and HPA controls are deliberately absent. A
headless Service supplies stable identity while the client Service exposes the
selected protocols.

## State and lifecycle

The entire `/var/lib/questdb` tree is mounted from one PVC. Chart-created PVCs
are retained by default. An existing claim can be selected for recovery. An
ephemeral volume is allowed only for evaluation and loses all database state.

StatefulSet updates replace the singleton in place. Before upgrades, operators
must create and verify a checkpoint-coordinated backup. A PodDisruptionBudget is
off by default because setting `minAvailable: 1` deliberately blocks voluntary
drains for a singleton.

## Authentication and configuration

QuestDB's upstream `admin`/`quest` PostgreSQL default is not used. Helm creates
and retains random PostgreSQL and HTTP passwords unless `questdb.existingSecret`
selects an operator-owned Secret. Both values are projected as files and passed
through `QDB_PG_PASSWORD_FILE` and `QDB_HTTP_PASSWORD_FILE`.

`questdb.serverConfig` maps documented properties to their `QDB_` environment
form. Direct secret values must not be placed there or in ordinary environment values. Additional
Secret projections are available for advanced cases such as the ILP TCP auth
database.

## Network and observability

HTTP 9000 and PostgreSQL 8812 are published by default. Legacy ILP TCP 9009 is
opt-in because ILP over HTTP is preferred. Health and metrics 9003 use a
separate Service only when metrics are enabled. NetworkPolicy applies distinct
peer lists to each interface and allows only DNS egress by default.

Ingress and Gateway API route only HTTP 9000 and require TLS configuration or a
TLS-terminating parent Gateway. PostgreSQL, ILP TCP and QWP traffic need a
trusted network or service mesh when encryption is required.

## Security model

The pod runs directly as UID/GID 10001 with `DO_CHOWN=false`, seccomp
RuntimeDefault, no privilege escalation, no capabilities, no API token and a
read-only root filesystem. The data PVC and `/tmp` are the only default writable
locations. Storage classes that do not honor `fsGroup` must be pre-provisioned
with ownership 10001 rather than weakening the workload security context.
