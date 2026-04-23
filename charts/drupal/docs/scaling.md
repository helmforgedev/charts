# Scaling

The Drupal chart can scale horizontally, but only when the underlying runtime is safe for shared state.

## Requirements For Multi-Replica Drupal

- `database.mode` must resolve to a MySQL-compatible database
- `persistence.enabled=true`
- `persistence.accessMode=ReadWriteMany`

If any of these requirements are missing, the chart fails fast during rendering.

## Autoscaling Example

```yaml
persistence:
  accessMode: ReadWriteMany

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5

pdb:
  enabled: true
  minAvailable: 1
```

This keeps the default single-replica behavior safe while still allowing production horizontal scaling when shared storage is available.
