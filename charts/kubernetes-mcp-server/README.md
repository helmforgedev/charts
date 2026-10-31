<!-- SPDX-License-Identifier: Apache-2.0 -->

# Kubernetes MCP Server Helm Chart

Kubernetes MCP Server exposes Kubernetes cluster inspection and automation through the Model Context Protocol.
This chart deploys the official `ghcr.io/containers/kubernetes-mcp-server:v0.0.67` image in HTTP mode with in-cluster authentication,
read-only safety flags, and least-privilege RBAC by default.

## Features

- Official pinned upstream image and Streamable HTTP transport.
- Read-only and destructive-operation safeguards enabled by default.
- In-cluster ServiceAccount authentication with `view` RBAC by default.
- Optional Ingress, Gateway API, NetworkPolicy, persistence, and PDB resources.
- Restricted pod and container security contexts compatible with OpenShift SCCs.
- ConfigMap checksum rollouts for custom TOML configuration.

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

## Configuration

The process listener is configured with `app.port`; `service.port` controls the
client-facing Service port. Use `app.env` for explicit variables, `app.envFrom`
for Secret or ConfigMap sources, and `mcp.configToml` for a complete upstream
configuration file.

| Value | Default | Purpose |
|---|---|---|
| `mcp.readOnly` | `true` | Disables mutating Kubernetes operations. |
| `mcp.disableDestructive` | `true` | Disables destructive tools. |
| `rbac.clusterRoleName` | `view` | Selects the ClusterRole bound to the pod. |
| `app.port` | `8080` | Sets the actual MCP HTTP listener. |
| `service.port` | `8080` | Sets the Service port exposed to clients. |
| `mcp.configToml` | empty | Mounts a complete TOML configuration file. |
| `networkPolicy.enabled` | `false` | Enables ingress and egress isolation. |

See [Operations](docs/operations.md), [Security](docs/security.md), and
[RBAC](docs/rbac.md) for the complete operational contract.

## Examples

Install the read-only default profile and connect locally:

```bash
helm install kubernetes-mcp-server helmforge/kubernetes-mcp-server
kubectl port-forward svc/kubernetes-mcp-server-kubernetes-mcp-server 8080:8080
```

Render the maintained production example before applying it:

```bash
curl -fsSLo kubernetes-mcp-server-production.yaml \
  https://raw.githubusercontent.com/helmforgedev/charts/main/charts/kubernetes-mcp-server/examples/production.yaml
helm template kubernetes-mcp-server helmforge/kubernetes-mcp-server \
  --values kubernetes-mcp-server-production.yaml
```

## Architecture

The Deployment receives MCP traffic through the Service and authenticates to
the Kubernetes API with its ServiceAccount token. Optional Ingress and
HTTPRoute resources expose the Service; the optional TOML ConfigMap and PVC are
mounted directly into the pod. See [DESIGN.md](DESIGN.md) for the topology and
trust boundaries.

## Security

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

The official image declares UID/GID `65532`, but the chart does not fix those
IDs so OpenShift SCCs can assign namespace-specific values. It requires
non-root execution with a read-only root filesystem, dropped capabilities, no
privilege escalation, and `RuntimeDefault` seccomp. These settings remain
configurable through `podSecurityContext` and `securityContext`.

For upgrade compatibility, an existing `podSecurityContext.runAsUser: 0`
override without `runAsNonRoot` remains valid and suppresses the chart's
automatic non-root flag. Set `runAsNonRoot` explicitly when both keys are
intended. New installations use non-root execution by default.

## Upgrade Notes

Version `0.0.67` removes the legacy SSE MCP transport, migrates token exchange
from `sts_*` settings to an explicit configuration block, and adds RBAC metadata,
metrics-port support and Kubernetes fixes. The chart already uses HTTP mode and
does not set the removed token-exchange options. Existing clients using SSE must
migrate to Streamable HTTP. Optional upstream environment variables can be
supplied through `app.extraEnv`; the default HTTP port and read-only chart
profile are unchanged.

The P2 quality update adds restrictive security defaults without renaming or
removing values. Upgrades retain all existing value keys. The pinned upstream
image already runs as a non-root user, while OpenShift may safely assign a
different non-root identity.

## Troubleshooting

- If the pod cannot reach Kubernetes, verify the ServiceAccount token and the
  ClusterRoleBinding selected by `rbac.clusterRoleName`.
- If probes fail after a port override, set `app.port` to the application
  listener; changing only `service.port` does not reconfigure the process.
- If NetworkPolicy is enabled, allow the cluster API endpoint through
  `networkPolicy.extraEgress` when it is not covered by the built-in rules.
- If a custom TOML file is rejected, inspect pod logs for the exact upstream
  validation error; a config checksum automatically rolls out valid changes.

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
