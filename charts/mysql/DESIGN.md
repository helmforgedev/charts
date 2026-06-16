# MySQL Chart Design

## Scope

The chart provides a pragmatic MySQL deployment for Kubernetes with two explicit modes:

- `standalone`: one writable MySQL instance for development, test, and simple stateful workloads.
- `replication`: one fixed writable source plus asynchronous read replicas for read scaling and recovery assistance.

The chart uses the official `docker.io/library/mysql` image and keeps database topology management inside Helm templates. It does not attempt to become a MySQL operator.

## Architecture

### Standalone

```text
Applications
     |
     v
+------------------+
| Service          |
| <release>-mysql  |
+------------------+
     |
     v
+------------------+
| StatefulSet      |
| mysql-0          |
| role=standalone  |
+------------------+
     |
     v
+------------------+
| PVC / data dir   |
+------------------+
```

Standalone mode is intentionally simple. It is valid for development and for production cases where a single writable instance is an accepted risk and external backup/restore processes are in place.

### Replication

```text
                 writes
Applications ----------------+
                              v
                    +------------------+
                    | Source Service   |
                    +------------------+
                              |
                              v
                    +------------------+
                    | source-0         |
                    | read_only=OFF    |
                    | GTID/binlog ON   |
                    +------------------+
                              |
                  async replication
                              |
             +----------------+----------------+
             v                                 v
    +------------------+              +------------------+
    | replica-0        |              | replica-1        |
    | read_only=ON     |              | read_only=ON     |
    +------------------+              +------------------+
             ^                                 ^
             +---------------+-----------------+
                             |
                       reads through
                    Replicas Service
```

Replication mode is for read scaling and operational recovery support. It does not provide automatic source election, source promotion, or transparent client failover.

### Secret and TLS Flow

```text
External secret store
        |
        | ExternalSecret (optional)
        v
Kubernetes Secrets
  - auth Secret
  - TLS Secret
  - backup Secret
        |
        +--> MySQL pods
        |      |
        |      +--> optional TLS permission init container
        |              copies Secret files to emptyDir
        |              chown 999:999, key chmod 0600
        |
        +--> Backup CronJob
```

The chart supports regular Kubernetes Secrets, existing Secrets, and External Secrets Operator v1. External Secrets are optional and disabled by default.

## Production Controls

Production-ready deployments are possible through values, but the default values are intentionally development-friendly. A production profile should usually enable or configure:

- externally managed auth credentials through `auth.existingSecret` or `externalSecrets.auth.enabled`.
- TLS with `tls.enabled`, `tls.requireSecureTransport`, and `tls.client.enabled`.
- `tls.volumePermissions.enabled` when projected TLS private-key modes are incompatible with the non-root MySQL process.
- persistent volumes sized for the workload and storage class.
- resource requests/limits or chart resource presets.
- `networkPolicy.enabled` and, where supported by the CNI, `networkPolicy.egress.enabled`.
- `serviceAccount.automountServiceAccountToken=false` unless an extension needs Kubernetes API access.
- metrics and alerts for availability, replica lag, connection count, disk growth, and backup failures.
- backup and restore runbooks with regular restore tests.

## Design Decisions

- Official image only: the chart does not depend on vendor-specific MySQL images.
- Fixed source replication: Helm owns a predictable source StatefulSet and replica StatefulSet.
- No raw secret material in values for production: use existing Kubernetes Secrets or External Secrets.
- TLS key permission normalization is opt-in because some clusters do not require it and it adds an init container.
- NetworkPolicy egress is opt-in because egress behavior varies by CNI and cluster policy.
- `service.ipFamilyPolicy` and `service.ipFamilies` are exposed for dual-stack clusters without changing single-stack defaults.

## Explicit Non-Goals

- InnoDB Cluster
- Group Replication
- automatic source promotion
- operator-style topology reconciliation
- physical backup orchestration
- point-in-time recovery automation
- cross-region disaster recovery

## Related Documents

- [README.md](README.md)
- [docs/production.md](docs/production.md)
- [docs/replication.md](docs/replication.md)
- [docs/replication-operations.md](docs/replication-operations.md)
- [docs/backup-restore.md](docs/backup-restore.md)
- [docs/secret-rotation.md](docs/secret-rotation.md)
