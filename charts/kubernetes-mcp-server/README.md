# Kubernetes MCP Server Helm Chart

Kubernetes MCP Server exposes Kubernetes cluster inspection and automation through the Model Context Protocol.
This chart deploys the official `ghcr.io/containers/kubernetes-mcp-server:v0.0.65` image in HTTP mode with in-cluster authentication,
read-only safety flags, and least-privilege RBAC by default.

## Install

```bash
helm repo add helmforge https://repo.helmforge.dev
helm install kubernetes-mcp-server helmforge/kubernetes-mcp-server
```

Defaults:

- `--read-only`
- `--disable-destructive`
- `--stateless`
- `--cluster-provider=in-cluster`
- `--disable-multi-cluster`
- ServiceAccount bound to the Kubernetes `view` ClusterRole

## Production Safety

Keep the default read-only profile for shared agent environments:

```yaml
mcp:
  readOnly: true
  disableDestructive: true
rbac:
  clusterRoleName: view
```

The chart blocks full write plus destructive mode unless `mcp.allowUnsafeWriteAccess=true` is set.
The chart is stateless by default.
If persistence is enabled and the Deployment is scaled above one replica, use `ReadWriteMany` storage or disable persistence to avoid sharing one `ReadWriteOnce` PVC across pods.
Ingress class rendering is optional. Set `ingress.ingressClassName: ""` to omit `spec.ingressClassName`.
When `networkPolicy.enabled=true`, ingress is restricted to the configured peers.
Setting `networkPolicy.enabled=true` enables egress isolation with built-in DNS and HTTPS allowances; `networkPolicy.extraEgress` appends API server or proxy rules.
Set `networkPolicy.dnsEgressPeers` when your cluster DNS pods do not use the default kube-system/kube-dns labels.

## Security Scan: `kubernetes-mcp-server`

| Framework | Score |
|---|---|
| Overall | **74.24%** |
| MITRE | **100.00%** |
| NSA | **62.50%** |
| SOC2 | **80.00%** |

> Security posture acceptable.

## Documentation

- [Operations](docs/operations.md)
- [Security](docs/security.md)
- [RBAC](docs/rbac.md)
- [Upstream project](https://github.com/containers/kubernetes-mcp-server)
