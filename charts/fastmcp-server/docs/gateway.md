# Gateway

Gateway mode mounts remote MCP servers behind one FastMCP Server endpoint.

```yaml
gateway:
  enabled: true
  mountServers:
    remote:
      transport: streamable-http
      url: https://remote.example.com/mcp
      namespace: remote
```

The chart renders this configuration as `MCP_MODE=gateway` and `MCP_MOUNT_SERVERS`.

For advanced cases, provide raw JSON:

```yaml
gateway:
  enabled: true
  rawMountServersJson: '{"remote":{"transport":"streamable-http","url":"https://remote.example.com/mcp","namespace":"remote"}}'
```

Gateway mode still uses the same client authentication settings as normal server mode. Configure `auth` to protect the gateway endpoint.

<!-- @AI-METADATA
type: chart-docs
title: FastMCP Server Gateway
description: Gateway mode guide for the FastMCP Server chart
keywords: fastmcp, gateway, mcp
purpose: Feature-specific chart documentation
scope: Chart
relations:
  - charts/fastmcp-server/values.yaml
  - charts/fastmcp-server/templates/deployment.yaml
path: charts/fastmcp-server/docs/gateway.md
version: 1.0
date: 2026-04-26
-->
