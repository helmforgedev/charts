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

## Scaling

The default deployment is stateless and can scale without persistence. If `persistence.enabled=true`, set `persistence.accessModes` to include `ReadWriteMany` before using `replicaCount > 1`.
