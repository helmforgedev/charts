# Langflow Scaling

Horizontal scaling requires shared state. The chart blocks `replicaCount > 1` unless `database.url` or `database.existingSecret` is set.
If persistence remains enabled, the mounted config directory must use shared storage with `ReadWriteMany`; the default generated `ReadWriteOnce` PVC is intentionally rejected for multi-replica deployments.

Example:

```yaml
replicaCount: 3
database:
  mode: external
  existingSecret: langflow-database
persistence:
  accessModes:
    - ReadWriteMany
pdb:
  enabled: true
resources:
  requests:
    cpu: 1000m
    memory: 2Gi
```

Scaling only the web/API pods does not automatically solve provider rate limits, custom component dependencies, or long-running flow execution capacity.
Validate representative flows under load before moving multi-replica releases to production.
