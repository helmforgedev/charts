# Kubernetes MCP Server Security

## Read-Only Default

The chart defaults to:

```yaml
mcp:
  readOnly: true
  disableDestructive: true
  disableMultiCluster: true
rbac:
  clusterRoleName: view
```

This keeps the server useful for diagnostics while avoiding cluster mutations.

## Write Access

Write access requires all of the following:

- `mcp.readOnly=false`
- appropriate RBAC
- `mcp.allowUnsafeWriteAccess=true` if destructive tools are enabled

Keep write-enabled releases isolated to trusted namespaces and clients.

## Exposure

Do not expose this service publicly. If Ingress or Gateway is enabled, put it behind strong identity, audit logging, and network restrictions.
