# GitHub MCP Server Chart Design

This chart runs the official GitHub MCP Server in streamable HTTP mode.
The service is intentionally stateless; persistence remains disabled by default and exists only as an escape hatch for future cache or custom state needs.
Because the workload is a Deployment, multi-replica releases with persistence enabled require `ReadWriteMany` storage; the chart rejects a shared `ReadWriteOnce` PVC for scaled deployments.

## Runtime Model

- Workload: Deployment.
- Protocol: MCP over streamable HTTP.
- Port: `8082` by default.
- Authentication to GitHub: `GITHUB_PERSONAL_ACCESS_TOKEN` from Secret.
- Access control: GitHub token scopes plus server-side `--read-only`, toolsets, allow-list, and deny-list arguments.

## Security Model

The MCP endpoint can execute GitHub API actions using the configured token.
The chart therefore defaults to `github.readOnly=true` and recommends private cluster exposure.
Ingress/Gateway should be protected by a trusted identity-aware proxy when enabled.

## Non-Goals

- Creating GitHub tokens.
- Managing GitHub App installation credentials.
- Implementing end-user authentication at the MCP server layer.
