# Qdrant Snapshots

Qdrant supports collection and full-storage snapshots through its API. This chart persists snapshots under:

```text
/qdrant/storage/snapshots
```

The path is controlled by:

```yaml
snapshots:
  path: /qdrant/storage/snapshots
```

## Create A Collection Snapshot

```bash
kubectl port-forward svc/qdrant 6333:6333
curl -X POST http://127.0.0.1:6333/collections/my_collection/snapshots
```

With API key authentication:

```bash
curl -H "api-key: $QDRANT_API_KEY" \
  -X POST http://127.0.0.1:6333/collections/my_collection/snapshots
```

## Restore

Restores are destructive for the target collection. Use Qdrant's snapshot restore API and test recovery in a separate namespace before applying to production.

Distributed deployments need per-node snapshot planning. The chart does not automate cross-node snapshot orchestration.
