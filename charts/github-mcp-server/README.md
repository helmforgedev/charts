# GitHub MCP Server Helm Chart

The GitHub MCP Server exposes GitHub APIs through the Model Context Protocol.
This chart deploys the official `ghcr.io/github/github-mcp-server:v1.2.0` image in streamable HTTP mode for internal agent platforms,
IDE integrations, and automation gateways.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install github-mcp-server helmforge/github-mcp-server
```

The default deployment starts the server in HTTP mode on port `8082`, read-only mode enabled, and the `default` toolset selected.
The chart is stateless by default.
If persistence is enabled and the Deployment is scaled above one replica, use `ReadWriteMany` storage or disable persistence to avoid sharing one `ReadWriteOnce` PVC across pods.

Ingress class rendering is optional. Set `ingress.ingressClassName: ""` to omit `spec.ingressClassName`.
When `networkPolicy.enabled=true`, ingress is restricted to the configured peers.
Setting `networkPolicy.extraEgress` also enables egress isolation with built-in DNS and HTTPS allowances, then appends the supplied proxy or API-server rules.

## Token Configuration

Use a Kubernetes Secret for production:

```yaml
github:
  existingSecret: github-mcp-token
  existingSecretKey: token
  requireToken: true
```

For GitHub Enterprise Server:

```yaml
github:
  host: ghe.example.com
```

Use the bare Enterprise hostname in values; the chart passes it to the upstream
server as an HTTPS API host.

## Tool Selection

Limit tools exposed to agents:

```yaml
github:
  readOnly: true
  toolsets: repos,issues,pull_requests
  excludeTools: create_issue,create_pull_request
```

## Security Scan: `github-mcp-server`

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
- [Toolsets](docs/toolsets.md)
- [GitHub MCP Server](https://github.com/github/github-mcp-server)
