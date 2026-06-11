# Qdrant Distributed Mode

Distributed mode is enabled with:

```yaml
replicaCount: 3
cluster:
  enabled: true
pdb:
  enabled: true
```

This sets `QDRANT__CLUSTER__ENABLED=true` and exposes the p2p port through a headless Service for stable peer DNS.

## Guardrails

The chart refuses unsafe combinations:

- one replica with `cluster.enabled=true`
- disabled persistence with `cluster.enabled=true`
- a shared `persistence.existingClaim` with `cluster.enabled=true`

## Operational Notes

Distributed Qdrant is not just a scale toggle.
Operators must understand shard placement, collection replication factors, snapshot strategy, and upgrade sequencing.
Use the official Qdrant distributed deployment documentation before enabling this in production.
