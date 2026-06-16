# Secret Rotation

## Scope

This chart supports password and TLS material through existing Kubernetes
Secrets, either created manually with `existingSecret` values or materialized by
External Secrets Operator through optional `externalSecrets.*` values. Rotation
remains an operational workflow outside the chart.

## Password rotation

- update the secret referenced by `auth.existingSecret`
- or update the external provider value referenced by `externalSecrets.auth.*RemoteRef`
- ensure the secret value matches the password stored in the existing data directory before restarting pods
- restart PostgreSQL workloads in a controlled maintenance window
- verify application connectivity after the rollout
- if replication is enabled, rotate replication credentials with care and confirm replicas can reconnect

If a PVC already contains a PostgreSQL data directory and the Secret is missing or was regenerated with a different value,
PostgreSQL keeps the old password in `pg_authid` while pods receive the new `POSTGRES_PASSWORD`.
The chart refuses unsafe password auto-generation when it detects the primary PVC.
Recover by restoring the correct Secret, rotating the database password intentionally, or reinitializing the data directory.

## TLS rotation

- update the secret referenced by `tls.existingSecret`
- or update the external provider value referenced by `externalSecrets.tls.*RemoteRef`
- roll the PostgreSQL pods so the new certificates are mounted and loaded
- validate server connectivity and client trust after the rollout
- if `tls.sslMode` uses `verify-ca` or stronger validation, confirm CA compatibility before restarting traffic

## Operational guidance

- avoid rotating passwords and TLS material in the same change unless necessary
- validate one environment at a time
- document rollback steps before rotation
- for production, use an external secret manager or an automated secret delivery workflow
- when External Secrets Operator is enabled, confirm the `ExternalSecret` reaches `Ready=True` before restarting PostgreSQL pods
- keep `config.localAuthMethod` at `scram-sha-256` unless a tightly controlled bootstrap/debug workflow explicitly requires `trust`
