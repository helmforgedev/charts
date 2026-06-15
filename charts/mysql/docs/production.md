# Production Hardening

The default values are intentionally useful for development. For production, start from `examples/production.yaml` and tune the
settings for your storage, networking, secret management, and operational requirements.

## Baseline production profile

Use these controls together:

- `architecture: replication` when read scaling is required.
- persistent storage enabled for the source and replicas.
- `auth.existingSecret` or `externalSecrets.auth.enabled=true` for credentials.
- `tls.enabled=true`, `tls.requireSecureTransport=true`, and `tls.client.enabled=true` for encrypted client and internal chart traffic.
- `tls.volumePermissions.enabled=true` when the TLS private key must be copied to a writable `emptyDir` and set to mode `0600` for the non-root MySQL process.
- `serviceAccount.automountServiceAccountToken=false` unless a sidecar explicitly needs Kubernetes API access.
- `networkPolicy.enabled=true`; add `networkPolicy.egress.enabled=true` when your CNI enforces egress.
- metrics, alerts, backup scheduling, and restore tests.

## External Secrets Operator

The chart renders `external-secrets.io/v1` resources when `externalSecrets.enabled=true`.

Structured blocks are available for separate secret lifecycles:

- `externalSecrets.auth` creates the MySQL auth Secret.
- `externalSecrets.tls` creates the TLS Secret used by MySQL.
- `externalSecrets.backup` creates the object-storage credentials Secret.

The `SecretStore` or `ClusterSecretStore` must exist before install. The chart does not install External Secrets Operator or provider credentials.

## TLS

TLS requires a Kubernetes Secret with:

- `ca.crt`
- `tls.crt`
- `tls.key`

Set `tls.requireSecureTransport=true` only after clients and replication bootstrap paths are configured for TLS. If MySQL rejects the projected private key due to permissions, enable `tls.volumePermissions.enabled=true`.

## NetworkPolicy

`networkPolicy.enabled=true` restricts ingress to the MySQL port and optional metrics port. `networkPolicy.egress.enabled=true` adds explicit egress rules for:

- DNS to kube-system.
- MySQL traffic to pods in the same namespace.
- optional HTTPS for external services.
- custom `extraTo` rules for environment-specific destinations.

Exact enforcement depends on the cluster CNI.

## Backup and Restore

The built-in backup is a logical `mysqldump --all-databases` to S3-compatible storage. It does not replace physical backup, binlog archival, or point-in-time recovery tooling for strict recovery objectives.

Validate restores regularly and treat failover, promotion, and rollback as documented operational runbooks.
