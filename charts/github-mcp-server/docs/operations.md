# GitHub MCP Server Operations

## Access

```bash
kubectl port-forward svc/github-mcp-server 8082:8082
```

Point compatible MCP clients at:

```text
http://127.0.0.1:8082
```

## Health

The chart uses TCP probes because MCP endpoints are client-protocol specific. Verify readiness with Kubernetes:

```bash
kubectl get deploy,pod,svc -l app.kubernetes.io/instance=github-mcp-server
kubectl logs deploy/github-mcp-server
```

## Upgrades

Before upgrading, check the upstream release notes for renamed tools, changed toolsets, or protocol changes. Keep token scopes minimal and test representative agent workflows against staging first.

The P2 security profile is disabled by default, so the previous runtime
identity and filesystem contract remain unchanged. Templates accept the new
map being absent during `--reuse-values`. Upgrade first, verify readiness, and
enable the profile only in a separate tested change.

```bash
helm upgrade github-mcp-server helmforge/github-mcp-server --reuse-values
kubectl rollout status deployment/github-mcp-server --timeout=300s
```

## Scaling

The default deployment is stateless and can scale without persistence. If `persistence.enabled=true`, set `persistence.accessModes` to include `ReadWriteMany` before using `replicaCount > 1`.

## Rollback and Token Rotation

Record the deployed chart version before an upgrade. If representative MCP
requests fail after rollout, inspect pod logs and GitHub API responses before
rolling back:

```bash
helm history github-mcp-server
helm rollback github-mcp-server <revision> --wait
```

A rollback restores Kubernetes manifests and chart values; it does not restore
or rotate an externally managed GitHub credential. Rotate tokens in the Secret,
then restart the Deployment so every pod receives the new environment value.
Confirm the configured `github.readOnly` mode after rotation. Exercise a
representative read operation from each enabled toolset for read-only releases;
for write-enabled releases, exercise the explicitly approved read or write
operation for each enabled toolset. Never print the Secret or token in
diagnostic output.

For scaled releases, wait until all replicas are Ready before directing clients
to the new version. Keep persistence disabled unless the runtime actually needs
it. If persistence is enabled, verify the existing claim supports the access
mode required by every replica and has a tested backup and restore process.
