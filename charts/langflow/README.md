# Langflow Helm Chart

Langflow is a visual builder for AI workflows, RAG applications, agents, and integrations with model providers and vector databases.
This HelmForge chart deploys the official `docker.io/langflowai/langflow:1.10.1` image with persistent local state by default and explicit
production paths for secret management, PostgreSQL-compatible databases, ingress, Gateway API, and horizontal scaling.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install langflow helmforge/langflow
```

The default deployment starts one Langflow pod on port `7860` and persists `/app/langflow`, which contains local configuration and the default SQLite database.
Ingress class rendering is optional. Set `ingress.ingressClassName: ""` to omit `spec.ingressClassName`.
When `networkPolicy.enabled=true`, ingress is restricted to the configured peers.
It also enables egress isolation with built-in DNS and HTTPS allowances, then appends `networkPolicy.extraEgress` for database, provider, or proxy rules.
Set `networkPolicy.dnsEgressPeers` when your cluster DNS pods do not use the default kube-system/kube-dns labels.

## Production Configuration

Set a stable `LANGFLOW_SECRET_KEY` so encrypted provider credentials and JWT signing survive pod restarts:

```yaml
auth:
  existingSecret: langflow-auth
  secretKeyKey: secret-key
  superuserKey: superuser
  superuserPasswordKey: superuser-password
```

Use an external PostgreSQL-compatible database before scaling horizontally:

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
```

The chart refuses `replicaCount > 1` unless `database.url` or `database.existingSecret` is set.
When persistence stays enabled for multiple replicas, the PVC must be shared safely with `ReadWriteMany`; otherwise disable persistence for ephemeral local config or keep a single replica.

## Provider Secrets

Flows often need provider credentials such as OpenAI, Anthropic, GitHub, Hugging Face, or vector database keys. Use `app.env` for explicit entries or `app.envFrom` to import a Secret:

```yaml
app:
  envFrom:
    - secretRef:
        name: langflow-provider-keys
```

## Security Scan: `langflow`

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
- [Database](docs/database.md)
- [Scaling](docs/scaling.md)
- [Langflow environment variables](https://docs.langflow.org/environment-variables)
- [Langflow Kubernetes production guide](https://docs.langflow.org/deployment-kubernetes-prod)
- [Langflow authentication](https://docs.langflow.org/api-keys-and-authentication)
