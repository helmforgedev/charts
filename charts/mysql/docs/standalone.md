# Standalone

## When to use it

Use `standalone` when you need one writable MySQL instance and want the smallest operational surface.

Typical use cases:

- development environments
- internal applications with modest write and read volume
- production environments where failover is handled outside the chart

## What it delivers

- one MySQL StatefulSet
- one client Service
- optional init scripts
- optional `mysqld-exporter`
- optional `ServiceMonitor`

## What it does not deliver

- read scaling
- automatic failover
- replica topology management

## Best practices

- keep persistence enabled in production
- set both `standalone.persistence.retentionPolicy.whenDeleted` and
  `standalone.persistence.retentionPolicy.whenScaled` to `Retain` when uninstall or scale-down must keep the PVC.
  Empty fields use the cluster default.
- use `auth.existingSecret` instead of inline passwords
- use `tls.enabled=true` with `tls.existingSecret` when client connections must be encrypted
- use `initdb.scripts` only for deterministic first-boot initialization
- keep backup and restore procedures outside the chart

Kubernetes 1.26 disables the `StatefulSetAutoDeletePVC` feature gate by default. Enable it on both the API server and
controller manager before relying on a `Delete` policy. Kubernetes 1.27 and later enable the feature by default.
