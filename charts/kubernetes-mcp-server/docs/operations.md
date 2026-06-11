# Kubernetes MCP Server Operations

## Access

```bash
kubectl port-forward svc/kubernetes-mcp-server 8080:8080
```

Point compatible MCP clients at:

```text
http://127.0.0.1:8080
```

## Verify RBAC

```bash
kubectl auth can-i list pods --as=system:serviceaccount:<namespace>:<service-account>
kubectl auth can-i delete pods --as=system:serviceaccount:<namespace>:<service-account>
```

The second command should be denied with default values.

## Troubleshooting

- Pod not ready: inspect args and logs.
- Kubernetes calls fail: verify ServiceAccount token mounting and RBAC.
- Tools missing: check `mcp.readOnly`, `mcp.disableDestructive`, and `mcp.toolsets`.
