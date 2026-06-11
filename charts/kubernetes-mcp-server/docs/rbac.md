# Kubernetes MCP Server RBAC

The chart creates a ClusterRoleBinding when:

```yaml
serviceAccount:
  create: true
rbac:
  create: true
```

Default:

```yaml
rbac:
  clusterRoleName: view
```

Use a custom ClusterRole for narrower access when possible. For example, bind only to specific namespaces or resource kinds by pre-creating a ClusterRole and setting `rbac.clusterRoleName`.
