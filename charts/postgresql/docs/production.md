# Production

The chart defaults are intentionally small and developer-friendly. Production deployments should use an explicit values file that turns on the controls required by the target platform.

## Baseline production values

Use [examples/production.yaml](../examples/production.yaml) as a starting point, then adjust storage classes, pod CIDRs, object storage endpoints, resources, and topology keys.

At minimum, production deployments should set:

- `auth.existingSecret`
- or `externalSecrets.auth.enabled=true` when External Secrets Operator is the platform standard
- persistent storage sizes and storage classes
- CPU and memory resources
- `metrics.enabled=true`
- `networkPolicy.enabled=true`
- backup configuration with restore tests
- explicit scheduling rules when multiple nodes or zones exist

## External Secrets Operator

The chart can optionally render `ExternalSecret` resources for clusters that
already run External Secrets Operator. It does not install the operator and does
not create a `SecretStore` or `ClusterSecretStore`.

Use this path when secret ownership belongs to a platform secret manager:

```yaml
externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  auth:
    enabled: true
    postgresPasswordRemoteRef:
      key: postgresql/auth
      property: postgres-password
    userPasswordRemoteRef:
      key: postgresql/auth
      property: user-password
```

When an ExternalSecret owns a target Secret, the chart suppresses the matching
native Secret and PostgreSQL consumes the materialized Kubernetes Secret. The
same pattern is available for `tls` and `backup` credentials.

## Network access

The compatibility default allows generated `pg_hba.conf` access from `0.0.0.0/0` and `::/0`. This keeps upgrades non-breaking, but production deployments should restrict:

```yaml
config:
  allowedClientCIDRs:
    - 10.42.0.0/16
  allowedReplicationCIDRs:
    - 10.42.0.0/16
```

`config.allowedReplicationCIDRs` covers both the replication pseudo-database and
the replication user's startup connections to the `postgres` maintenance
database. Replicas need those maintenance connections for readiness checks and
optional replication slot creation before `pg_basebackup` starts streaming.

Pair PostgreSQL-level access rules with Kubernetes NetworkPolicy:

```yaml
networkPolicy:
  enabled: true
  egress:
    enabled: true
```

## TLS

PostgreSQL requires restrictive permissions on the server private key. Kubernetes Secrets may mount key files with permissions PostgreSQL rejects in some environments.

Enable the permission normalization init container when needed:

```yaml
tls:
  enabled: true
  existingSecret: postgresql-tls
  volumePermissions:
    enabled: true
```

The init container copies certificate material from the Secret into an `emptyDir`, sets the private key to `0600`, and runs PostgreSQL against the corrected mount.

If TLS material is delivered by External Secrets Operator, set
`externalSecrets.tls.enabled=true` instead of `tls.existingSecret`. The target
Secret must contain the keys configured by `tls.certFilename`,
`tls.keyFilename`, and `tls.caFilename`.

## Replication slots

Replication slots can prevent a lagging replica from losing required WAL, but they can also retain WAL until disk pressure becomes dangerous. Use them only with retention limits and monitoring:

```yaml
replication:
  slots:
    enabled: true
  wal:
    maxSlotWalKeepSize: 8GB
    idleReplicationSlotTimeout: 24h
    walSenderTimeout: 60s
```

Monitor `pg_replication_slots`, WAL directory growth, disk usage, and replica lag.

## Service account

PostgreSQL pods do not need Kubernetes API credentials by default:

```yaml
serviceAccount:
  create: true
  automountServiceAccountToken: false
```

Only enable token automounting for a specific integration that needs it.

## Scope boundary

This chart does not implement automatic failover, fencing, promotion orchestration,
PITR, or cluster reconciliation. Use a PostgreSQL operator when production
requirements include automated HA lifecycle management.
