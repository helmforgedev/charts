# FastMCP Server

A Helm chart for deploying [FastMCP Server](https://github.com/helmforgedev/fastmcp-server) on Kubernetes using the official [`docker.io/helmforge/fastmcp-server`](https://hub.docker.com/r/helmforge/fastmcp-server) image. Dynamically loads MCP tools, resources, prompts, and knowledge bases from inline ConfigMaps, S3-compatible storage, or Git repositories.

## Features

- Multi-source loading with merge precedence: Inline > S3 > Git
- Bearer token and JWT authentication via FastMCP
- Multi-provider authentication with bearer and JWT
- Dedicated admin token and destructive-tool approval controls
- Knowledge base files served as MCP resources
- Extra pip packages installed at startup
- S3, Git, and OCI sources with optional background sync
- Gateway mode for mounting remote MCP servers
- Tool visibility filtering by tags
- Built-in Web UI dashboard at `/ui`
- Prometheus metrics with ServiceMonitor support
- Structured JSON logging for log aggregation
- Dedicated health endpoints (`/healthz`, `/readyz`, `/startupz`)
- Diagnostic endpoint at `/debug/info`
- Init container pattern for source pre-sync

## Quick Start

```bash
helm install fastmcp-server oci://ghcr.io/helmforgedev/helm/fastmcp-server
```

With inline tools:

```bash
helm install fastmcp-server oci://ghcr.io/helmforgedev/helm/fastmcp-server \
  --set-file sources.inline.tools.greet\.py=examples/tools/greet.py
```

With bearer authentication:

```bash
helm install fastmcp-server oci://ghcr.io/helmforgedev/helm/fastmcp-server \
  --set auth.type=bearer \
  --set auth.bearer.token=my-secret-token
```

## Configuration

### Inline Tools

Define Python tool files directly in `values.yaml`:

```yaml
sources:
  inline:
    tools:
      greet.py: |
        def greet(name: str) -> str:
            """Greet someone by name."""
            return f"Hello, {name}!"
      math_ops.py: |
        def add(a: float, b: float) -> float:
            """Add two numbers."""
            return a + b
    resources:
      status.py: |
        import json
        RESOURCE_URI = "status://server"
        def get_status() -> str:
            """Server status."""
            return json.dumps({"status": "healthy"}, indent=2)
    prompts:
      summarize.py: |
        def summarize(text: str) -> str:
            """Summarize text."""
            return f"Please summarize:\n\n{text}"
    knowledge:
      overview.md: |
        # Product Overview
        Context document for the AI assistant.
```

### S3 Source

Load tools from an S3-compatible bucket (AWS S3, MinIO, Cloudflare R2):

```yaml
sources:
  s3:
    enabled: true
    endpoint: "https://minio.example.com"
    bucket: mcp-tools
    region: us-east-1
    prefix: production
    accessKey: "<access-key>"
    secretKey: "<secret-key>"
```

Or with an existing secret:

```yaml
sources:
  s3:
    enabled: true
    bucket: mcp-tools
    existingSecret: my-s3-credentials
    existingSecretAccessKeyKey: access-key
    existingSecretSecretKeyKey: secret-key
```

### Git Source

Clone tools from a Git repository at startup:

```yaml
sources:
  git:
    enabled: true
    repository: "https://github.com/your-org/mcp-tools.git"
    branch: main
    path: ""
    token: "<github-token>"  # for private repos
```

### Authentication

Bearer token:

```yaml
auth:
  type: bearer
  bearer:
    token: my-secret-token
```

JWT:

```yaml
auth:
  type: jwt
  jwt:
    issuer: "https://auth.example.com"
    audience: "mcp-server"
    jwksUri: "https://auth.example.com/.well-known/jwks.json"
```

Multi-provider authentication:

```yaml
auth:
  type: multi
  providers:
    - bearer
    - jwt
  adminExistingSecret: fastmcp-admin
  adminExistingSecretKey: admin-token
```

See [Authentication](docs/authentication.md) for bearer, JWT, multi-provider,
and reload admin token examples.

### Gateway Mode

```yaml
gateway:
  enabled: true
  mountServers:
    remote:
      transport: streamable-http
      url: https://remote.example.com/mcp
      namespace: remote
```

See [Gateway](docs/gateway.md) for gateway mode details.

### Source Sync

```yaml
sources:
  s3:
    enabled: true
    bucket: mcp-assets
    syncInterval: 60
```

See [Sources](docs/sources.md) for inline, S3, Git, OCI, and hot reload
configuration.

### Observability

Enable Prometheus metrics and ServiceMonitor:

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
```

Structured JSON logging:

```yaml
server:
  logFormat: json
```

### Init Container Pattern

Pre-sync sources before the server starts:

```yaml
initSync:
  enabled: true
```

### Production Example

```yaml
server:
  name: production-mcp
  logLevel: WARNING
  logFormat: json

auth:
  type: bearer
  bearer:
    existingSecret: mcp-auth

sources:
  s3:
    enabled: true
    bucket: mcp-production
    existingSecret: mcp-s3-credentials
  inline:
    knowledge:
      runbook.md: |
        # Operations Runbook
        Emergency procedures for the production environment.

extraPipPackages:
  - requests
  - pandas

metrics:
  enabled: true
  serviceMonitor:
    enabled: true

initSync:
  enabled: true

ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
    - host: mcp.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - mcp.example.com
      secretName: mcp-tls

persistence:
  enabled: true
  size: 5Gi

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

podSecurityContext:
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  runAsNonRoot: true
```

## Default Values

| Key | Default | Description |
|-----|---------|-------------|
| `image.repository` | `docker.io/helmforge/fastmcp-server` | Container image |
| `image.tag` | `0.11.1` | Image tag |
| `server.name` | `fastmcp-server` | Server name in MCP responses |
| `server.environment` | `dev` | Runtime environment passed as `MCP_ENV` |
| `server.workspace` | `/app/workspace` | Workspace path for synced components |
| `server.port` | `8000` | HTTP port |
| `server.path` | `/mcp` | MCP endpoint path |
| `server.logLevel` | `INFO` | Log level |
| `server.logFormat` | `text` | Log format: `text` or `json` |
| `ui.enabled` | `true` | Enable Web UI at `/ui` |
| `metrics.enabled` | `false` | Enable Prometheus metrics at `/metrics` |
| `metrics.serviceMonitor.enabled` | `false` | Create ServiceMonitor CRD |
| `auth.type` | `none` | Authentication: `none`, `bearer`, `jwt`, `multi` |
| `auth.adminToken` | `""` | Dedicated admin token for privileged endpoints such as `/reload` |
| `auth.adminExistingSecret` | `""` | Existing Secret containing the admin token |
| `sources.inline.tools` | `{}` | Inline Python tool files |
| `sources.inline.resources` | `{}` | Inline Python resource files |
| `sources.inline.prompts` | `{}` | Inline Python prompt files |
| `sources.inline.knowledge` | `{}` | Inline knowledge base files |
| `sources.s3.enabled` | `false` | Enable S3 source |
| `sources.s3.bucket` | `""` | S3 bucket name |
| `sources.s3.syncInterval` | `0` | Periodic S3 sync interval in seconds |
| `sources.git.enabled` | `false` | Enable Git source |
| `sources.git.repository` | `""` | Git repository HTTPS URL |
| `sources.git.syncInterval` | `0` | Periodic Git sync interval in seconds |
| `sources.oci.enabled` | `false` | Enable OCI source |
| `gateway.enabled` | `false` | Enable gateway mode |
| `visibility.mode` | `blocklist` | Tool visibility strategy |
| `extraPipPackages` | `[]` | Extra pip packages at startup |
| `initSync.enabled` | `false` | Run source sync as init container |
| `persistence.enabled` | `false` | Enable persistent workspace |
| `serviceAccount.create` | `true` | Create a dedicated Kubernetes ServiceAccount |
| `ingress.enabled` | `false` | Enable ingress |
| `networkPolicy.enabled` | `false` | Enable NetworkPolicy |

See [`values.yaml`](values.yaml) for the full configuration reference.

## Connecting MCP Clients

After deploying the chart, connect AI assistants to the MCP endpoint.

### Claude Code

Add to your Claude Code settings (`~/.claude/settings.json` or project `.claude/settings.json`):

```json
{
  "mcpServers": {
    "my-mcp-server": {
      "type": "streamable-http",
      "url": "https://mcp.example.com/mcp",
      "headers": {
        "Authorization": "Bearer <your-token>"
      }
    }
  }
}
```

The URL is your ingress host + the `server.path` value (default `/mcp`).

### Codex (VS Code Extension)

Add to your Codex configuration (`~/.codex/config.toml`):

```toml
[mcp_servers.my-mcp-server]
enabled = true
url = "https://mcp.example.com/mcp"

[mcp_servers.my-mcp-server.http_headers]
Authorization = "Bearer <your-token>"
```

### Port-Forward (Development)

For local testing without ingress:

```bash
kubectl port-forward svc/fastmcp-server 8000:8000
```

Then use `http://localhost:8000/mcp` as the URL (no auth if `auth.type=none`).

## Examples

- [Basic inline tools](examples/basic/)
- [S3 source with MinIO](examples/s3-minio/)
- [Production setup](examples/production/)
- [Production S3 source](examples/production-s3-values.yaml)
- [Gateway mode](examples/gateway-values.yaml)
- [JWT authentication](examples/jwt-values.yaml)
- [Multi-auth](examples/multi-auth-values.yaml)
- [Development hot reload](examples/dev-hot-reload-values.yaml)

## Architecture Guides

- [Authentication](docs/authentication.md)
- [Sources](docs/sources.md)
- [Gateway](docs/gateway.md)
- [Operations](docs/operations.md)

<!-- @AI-METADATA
type: chart-readme
title: fastmcp-server
description: Helm chart README for FastMCP server with multi-source tool loading
keywords: mcp, fastmcp, ai, llm, tools, knowledge-base, helm
purpose: Chart README with installation, configuration, and usage
scope: Chart
relations:
  - charts/fastmcp-server/values.yaml
  - charts/fastmcp-server/Chart.yaml
path: charts/fastmcp-server/README.md
version: 1.2
date: 2026-04-05
-->
