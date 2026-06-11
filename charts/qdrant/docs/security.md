# Qdrant Security

## API Keys

Enable API key authentication with an existing Secret:

```yaml
auth:
  existingSecret: qdrant-api-keys
  apiKeyKey: api-key
  readOnlyApiKeyKey: read-only-api-key
```

The chart maps those keys to:

- `QDRANT__SERVICE__API_KEY`
- `QDRANT__SERVICE__READ_ONLY_API_KEY`

Use the read-only key for query-only clients and reserve the write key for ingestion, schema management, and administrative automation.

## Network Exposure

Expose only the HTTP API externally.
The gRPC API is available on the client Service for internal high-throughput clients.
The p2p port is only on the headless Service and should remain cluster-internal.

For stricter clusters, enable NetworkPolicy:

```yaml
networkPolicy:
  enabled: true
  ingressFrom:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: rag
```

## TLS

Ingress and Gateway TLS termination should normally happen at the ingress controller or Gateway.
Qdrant also supports native TLS through its configuration file; use `config.localYaml` and mount certificates through `extraVolumes` when
that is required.
