<!-- SPDX-License-Identifier: Apache-2.0 -->

# GitHub MCP Server Helm Chart

The GitHub MCP Server exposes GitHub APIs through the Model Context Protocol.
This chart deploys the official `ghcr.io/github/github-mcp-server:v1.9.0` image in streamable HTTP mode for internal agent platforms,
IDE integrations, and automation gateways.

## Features

- Official pinned GitHub MCP Server image in streamable HTTP mode.
- GitHub.com and GitHub Enterprise Server support.
- Read-only mode, toolsets, explicit tool allow-list, and deny-list controls.
- Existing Secret support for production token management.
- Optional Ingress, Gateway API, NetworkPolicy, PDB, and persistence.
- Opt-in compatible security profile with explicit override precedence.

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

Nonempty `app.args` replaces all generated arguments, including the chart's
read-only and tool-selection flags. Use it only when you intend to own the
complete upstream command line.

## Upgrade Compatibility

The P2 baseline keeps the `1.0.4` default security render unchanged.
`securityProfile.enabled` defaults to `false`, and templates tolerate the new
map being absent during `--reuse-values` upgrades.

```bash
helm upgrade github-mcp-server helmforge/github-mcp-server --reuse-values
kubectl rollout status deployment/github-mcp-server --timeout=300s
```

Enable the profile only after the baseline upgrade is healthy:

```yaml
securityProfile:
  enabled: true
```

The profile adds RuntimeDefault seccomp, a read-only root filesystem, disabled
privilege escalation, and dropped capabilities. It does not force a numeric
user because the official image metadata declares UID 0. Explicit
`podSecurityContext` and `securityContext` values take precedence.

## Configuration Highlights

| Key | Default | Purpose |
| --- | --- | --- |
| `app.port` | `8082` | Real MCP HTTP listener port |
| `github.readOnly` | `true` | Filter write tools from generated arguments |
| `github.toolsets` | `default` | Enabled upstream toolsets |
| `github.existingSecret` | `""` | Production token Secret |
| `serviceAccount.automountServiceAccountToken` | `false` | Keep Kubernetes credentials out of the pod |
| `networkPolicy.enabled` | `false` | Enable ingress policy |
| `securityProfile.enabled` | `false` | Enable compatible hardening defaults |
| `replicaCount` | `1` | HTTP server replicas |
| `github.host` | `""` | GitHub Enterprise hostname |
| `github.tools` | `""` | Explicit tool allow-list |
| `github.excludeTools` | `""` | Explicit tool deny-list |
| `github.requireToken` | `false` | Fail rendering without a token source |
| `persistence.enabled` | `false` | Mount optional application storage |
| `pdb.enabled` | `false` | Create a PodDisruptionBudget |
| `ingress.enabled` | `false` | Create an Ingress |
| `gateway.enabled` | `false` | Create a Gateway API HTTPRoute |
| `service.port` | `8082` | Cluster-facing Service port |
| `probes.startup.enabled` | `true` | Gate startup on the TCP listener |
| `resources` | `{}` | Pod CPU and memory requests and limits |
| `terminationGracePeriodSeconds` | `30` | Graceful shutdown window |

## Examples

- [Simple internal server](examples/simple.yaml) keeps the endpoint private and
  uses the default read-only tool surface.
- [Production server](examples/production.yaml) demonstrates an existing token
  Secret, bounded resources, availability controls, and private exposure.

Render an example before applying it:

```bash
helm template github-mcp-server ./charts/github-mcp-server \
  --values ./charts/github-mcp-server/examples/production.yaml
```

## Architecture

MCP clients reach a ClusterIP Service or an authenticated Ingress/Gateway. The
Deployment reads a GitHub credential from a Secret and calls GitHub.com or GHES
over HTTPS. The runtime is stateless by default, so replicas can scale without
shared storage. See [DESIGN.md](DESIGN.md) for trust boundaries and
[operations](docs/operations.md) for rollout and scaling guidance.

## Troubleshooting

- If the server starts without the expected restrictions, verify that
  `app.args` is empty so chart-generated flags are active.
- If GitHub returns authentication errors, verify the Secret key and token
  scopes without printing the credential.
- If GHES is unreachable under egress isolation, add its destination to
  `networkPolicy.extraEgress`.
- If the hardened profile blocks a custom binary or writable path, add the
  smallest explicit `securityContext` exception after review.

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
