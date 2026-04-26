# Operations

## Runtime Environment

The chart exposes the server runtime controls directly under `server`.

```yaml
server:
  environment: production
  logFormat: json
  strictLoading: true
  maskErrorDetails: true
  onDuplicateTools: warn
```

## Visibility

```yaml
visibility:
  mode: blocklist
  disableTags:
    - admin
```

Use allowlist mode for tightly scoped deployments:

```yaml
visibility:
  mode: allowlist
  enableTags:
    - public
```

## Limits

```yaml
server:
  maxSourceFileSizeBytes: 1048576
  maxKnowledgeBytes: 10485760

sandboxing:
  maxMemoryMb: 256
  maxOutputSizeKb: 1024
```

Memory enforcement is best-effort and depends on the Linux runtime. Output truncation is enforced by the FastMCP server.

## Validation Commands

```bash
helm lint charts/fastmcp-server --strict
helm template test-release charts/fastmcp-server
helm unittest charts/fastmcp-server
```

Runtime validation should use a k3d context and inspect logs for every chart-created pod/container.

<!-- @AI-METADATA
type: chart-docs
title: FastMCP Server Operations
description: Operations guide for the FastMCP Server chart
keywords: fastmcp, operations, limits, visibility, validation
purpose: Feature-specific chart documentation
scope: Chart
relations:
  - charts/fastmcp-server/values.yaml
  - charts/fastmcp-server/templates/NOTES.txt
path: charts/fastmcp-server/docs/operations.md
version: 1.0
date: 2026-04-26
-->
