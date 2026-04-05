# FastMCP Server

A Helm chart for deploying [FastMCP Server](https://github.com/helmforgedev/fastmcp-server) on Kubernetes using the official [`docker.io/helmforge/fastmcp-server`](https://hub.docker.com/r/helmforge/fastmcp-server) image. Dynamically loads MCP tools, resources, prompts, and knowledge bases from inline ConfigMaps, S3-compatible storage, or Git repositories.

## Features

- Multi-source loading with merge precedence: Inline > S3 > Git
- Bearer token and JWT authentication via FastMCP
- Knowledge base files served as MCP resources
- Extra pip packages installed at startup
- Built-in Web UI dashboard at `/ui`
- Prometheus metrics with ServiceMonitor support
- Structured JSON logging for log aggregation
- Dedicated health endpoints (`/healthz`, `/readyz`, `/startupz`)
- Diagnostic endpoint at `/debug/info`
- Init container pattern for source pre-sync
- Strict loading mode for fail-fast on errors

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
        RESOURCE_URI = "status://server"
        def get_status() -> dict:
            """Server status."""
            return {"status": "healthy"}
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
    accessKey: minioadmin
    secretKey: minioadmin
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
    token: ghp_xxx  # for private repos
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
  strictLoading: true

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
| `image.tag` | `0.4.0` | Image tag |
| `server.name` | `fastmcp-server` | Server name in MCP responses |
| `server.port` | `8000` | HTTP port |
| `server.path` | `/mcp` | MCP endpoint path |
| `server.logLevel` | `INFO` | Log level |
| `server.logFormat` | `text` | Log format: `text` or `json` |
| `server.strictLoading` | `false` | Fail on boot if any component has errors |
| `ui.enabled` | `true` | Enable Web UI at `/ui` |
| `metrics.enabled` | `false` | Enable Prometheus metrics at `/metrics` |
| `metrics.serviceMonitor.enabled` | `false` | Create ServiceMonitor CRD |
| `auth.type` | `none` | Authentication: `none`, `bearer`, `jwt` |
| `sources.inline.tools` | `{}` | Inline Python tool files |
| `sources.inline.resources` | `{}` | Inline Python resource files |
| `sources.inline.prompts` | `{}` | Inline Python prompt files |
| `sources.inline.knowledge` | `{}` | Inline knowledge base files |
| `sources.s3.enabled` | `false` | Enable S3 source |
| `sources.s3.bucket` | `""` | S3 bucket name |
| `sources.git.enabled` | `false` | Enable Git source |
| `sources.git.repository` | `""` | Git repository HTTPS URL |
| `extraPipPackages` | `[]` | Extra pip packages at startup |
| `initSync.enabled` | `false` | Run source sync as init container |
| `persistence.enabled` | `false` | Enable persistent workspace |
| `ingress.enabled` | `false` | Enable ingress |
| `networkPolicy.enabled` | `false` | Enable NetworkPolicy |

See [`values.yaml`](values.yaml) for the full configuration reference.

## Examples

- [Basic inline tools](examples/basic/)
- [S3 source with MinIO](examples/s3-minio/)
- [Production setup](examples/production/)

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
