# Qdrant Operations

## Health Checks

The chart uses TCP startup, liveness, and readiness probes against the HTTP port. After installation, verify the pod, endpoints, and API:

```bash
kubectl get statefulset,pod,svc -l app.kubernetes.io/instance=qdrant
kubectl port-forward svc/qdrant 6333:6333
curl http://127.0.0.1:6333/readyz
```

When API key authentication is enabled:

```bash
curl -H "api-key: $QDRANT_API_KEY" http://127.0.0.1:6333/collections
```

## Configuration

Qdrant supports layered configuration. This chart uses two operator-facing paths:

- `config.localYaml` renders `/qdrant/config/local.yaml`.
- `app.env` accepts explicit `QDRANT__...` environment variables.

Environment variables have the highest priority in Qdrant, so use them for small overrides and `config.localYaml` for structured configuration that should be reviewable in Git.

## Upgrades

Before upgrading:

1. Read the Qdrant release notes for storage or API changes.
2. Create collection or storage snapshots for critical data.
3. Confirm PVC capacity and node disk pressure.
4. Upgrade one environment at a time and verify `/collections` and `/metrics`.

For distributed deployments, plan upgrades more carefully. The chart does not automate Qdrant cluster rebalancing or zero-downtime shard migration.
