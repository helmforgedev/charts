# Kubernetes MCP Server Chart Design

This chart runs Kubernetes MCP Server as an in-cluster HTTP MCP endpoint.
Unlike general web applications, this workload is a control-plane bridge: its effective permissions are the Kubernetes RBAC permissions granted
to its ServiceAccount.

## Runtime Model

- Workload: Deployment.
- Protocol: MCP over HTTP.
- Authentication to Kubernetes: in-cluster ServiceAccount token.
- Default RBAC: ClusterRoleBinding to `view`.
- Safety flags: read-only, destructive operations disabled, stateless mode.

## Security Model

The chart defaults to inspection-only operation.
Write access requires both command-line mode changes and stronger RBAC.
Fully destructive write access is blocked by template validation unless `mcp.allowUnsafeWriteAccess=true` is set.

## Non-Goals

- Managing kubeconfigs for out-of-cluster access.
- Granting cluster-admin by default.
- Providing public internet exposure for a cluster-control MCP endpoint.
