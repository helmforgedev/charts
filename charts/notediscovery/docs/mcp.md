# NoteDiscovery MCP Integration

NoteDiscovery includes MCP integration in the upstream application. The Helm chart does not create separate MCP resources; it deploys the upstream web application and its persistent data volume.

Use `auth.apiKey` or an existing `config.yaml` Secret when MCP clients or automation need API-key access:

```yaml
auth:
  enabled: true
  secretKey: replace-with-a-long-random-secret
  password: replace-with-a-strong-password
  apiKey: replace-with-a-long-random-api-key
```

For production, prefer `auth.existingSecret` so the API key is not stored in Helm values.

Restrict network access with Ingress authentication, Gateway policy, or `networkPolicy.enabled=true` when exposing MCP-capable endpoints outside a trusted network.
