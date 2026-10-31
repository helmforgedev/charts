<!-- SPDX-License-Identifier: Apache-2.0 -->

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

The official image runs as UID/GID `65532`. The chart requires a non-root
identity without fixing numeric IDs, which allows OpenShift SCCs to assign the
namespace-specific ranges they require. It also enables `RuntimeDefault`
seccomp, a read-only root filesystem, dropped Linux capabilities, and disabled
privilege escalation by default. The ServiceAccount token remains mounted
because in-cluster Kubernetes authentication requires it.

## Write Access

Write access requires all of the following:

- `mcp.readOnly=false`
- appropriate RBAC
- `mcp.allowUnsafeWriteAccess=true` if destructive tools are enabled

Keep write-enabled releases isolated to trusted namespaces and clients.

## Exposure

Do not expose this service publicly. If Ingress or Gateway is enabled, put it behind strong identity, audit logging, and network restrictions.
