# Qdrant Helm Chart

Qdrant is a vector database and similarity search engine for embeddings, payload filters, semantic search, retrieval-augmented generation,
recommendation, and matching workloads.
This HelmForge chart deploys the official `docker.io/qdrant/qdrant:v1.18.2` image with persistent storage, HTTP and gRPC services,
optional API key authentication, snapshot storage, Prometheus scraping, and guarded distributed-mode settings.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install qdrant helmforge/qdrant
```

The default deployment is a single persistent StatefulSet with:

- HTTP API on port `6333`
- gRPC API on port `6334`
- peer discovery service with Qdrant p2p port `6335`
- storage mounted at `/qdrant/storage`
- snapshots stored under `/qdrant/storage/snapshots`

## Production Configuration

Use an existing Secret for API keys in production:

```yaml
auth:
  existingSecret: qdrant-api-keys
  apiKeyKey: api-key
  readOnlyApiKeyKey: read-only-api-key
```

For environment-specific Qdrant options, prefer `config.localYaml` for structured configuration and `app.env` for targeted `QDRANT__...` overrides:

```yaml
config:
  localYaml: |
    log_level: INFO
    storage:
      performance:
        max_search_threads: 4
```

## Distributed Mode

Distributed mode is intentionally guarded. Enable it only when you understand Qdrant cluster operations and have persistent per-pod volumes:

```yaml
replicaCount: 3
cluster:
  enabled: true
pdb:
  enabled: true
```

The chart fails rendering when `cluster.enabled=true` is combined with one replica, disabled persistence, or a shared `persistence.existingClaim`.
When enabled, the StatefulSet starts ordinal 0 with a stable `--uri`; later pods join through `--bootstrap` and publish their own stable peer URI.

## Monitoring

Qdrant exposes Prometheus metrics on `/metrics`. Enable a ServiceMonitor when Prometheus Operator CRDs are installed:

```yaml
metrics:
  serviceMonitor:
    enabled: true
    labels:
      release: prometheus
```

## Security Scan: `qdrant`

| Framework | Score |
|---|---|
| Overall | **75.76%** |
| MITRE | **100.00%** |
| NSA | **65.00%** |
| SOC2 | **80.00%** |

> Security posture acceptable.

## Documentation

- [Operations](docs/operations.md)
- [Security](docs/security.md)
- [Snapshots](docs/snapshots.md)
- [Distributed mode](docs/distributed.md)
- [Qdrant configuration](https://qdrant.tech/documentation/ops-configuration/configuration/)
- [Qdrant monitoring](https://qdrant.tech/documentation/ops-monitoring/monitoring/)
- [Qdrant snapshots](https://qdrant.tech/documentation/snapshots/)
