# GitHub MCP Server Security

## Token Scope

Use the least privileged token that supports the intended toolsets. Prefer read-only repository scopes for inspection-only agents.

```yaml
github:
  existingSecret: github-mcp-token
  requireToken: true
  readOnly: true
```

## Exposure

Do not expose the MCP endpoint directly to the public internet. If Ingress or Gateway is enabled, place it behind an identity-aware proxy, VPN, or internal-only load balancer.

## Write Tools

Set `github.readOnly=false` only for controlled automation. Combine it with `github.tools` or `github.excludeTools` to make the intended write surface explicit.

## Optional Security Profile

`securityProfile.enabled=true` applies RuntimeDefault seccomp, a read-only root
filesystem, disabled privilege escalation, and dropped Linux capabilities.
Explicit pod and container security-context values override profile defaults.
The profile deliberately does not force a numeric UID because the official
image metadata declares root and Kubernetes platforms may assign identities.

Test custom commands, extra volumes, and persistence before enabling it. The
default remains disabled to avoid changing existing installations during an
upgrade.
