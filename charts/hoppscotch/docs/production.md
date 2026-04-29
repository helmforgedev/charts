# Production Hardening Guide

## DATA_ENCRYPTION_KEY

The `DATA_ENCRYPTION_KEY` encrypts sensitive data (OAuth tokens, etc.) stored in PostgreSQL.

**Critical rules:**
- Must be exactly 32 characters
- Auto-generated on first install if not provided
- **Never change after first install** — it will corrupt all encrypted data
- Back up this key alongside your database backup

### Generating a Secure Key

```bash
openssl rand -hex 16   # 32 hex characters
```

### Using ExternalSecrets (recommended)

```yaml
encryption:
  existingSecret: hoppscotch-secrets
  existingSecretKey: data-encryption-key
```

Do not store the key in values.yaml in production.

## ExternalSecrets Operator

With the External Secrets Operator, all sensitive values are fetched from a secret manager:

```yaml
externalSecrets:
  enabled: true
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  data:
    - secretKey: database-url
      remoteRef:
        key: prod/hoppscotch
        property: database-url
    - secretKey: data-encryption-key
      remoteRef:
        key: prod/hoppscotch
        property: data-encryption-key
```

When `externalSecrets.enabled=true`, the chart creates an ExternalSecret resource instead of a Secret. The secret.yaml still renders (for checksums), but credentials come from the store.

## TLS via cert-manager

```yaml
ingress:
  enabled: true
  className: nginx
  host: hoppscotch.example.com
  tls:
    - secretName: hoppscotch-tls
      hosts:
        - hoppscotch.example.com
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
```

## WebSocket Support

WebSocket is required for real-time collaboration. Add these annotations to your ingress:

```yaml
ingress:
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
```

For Traefik, use middleware with websocket passthrough configured.

## Multi-Replica Deployment

Hoppscotch is fully stateless — all state lives in PostgreSQL. Horizontal scaling is safe:

```yaml
replicaCount: 3
podDisruptionBudget:
  enabled: true
  minAvailable: 2
```

For HA PostgreSQL, use an external managed database or the PostgreSQL subchart with replication enabled.

## Network Policy

Restrict ingress/egress to only what Hoppscotch needs:

```yaml
networkPolicy:
  enabled: true
```

The default policy allows:
- Ingress: from any pod in the same namespace on port 80
- Egress: DNS (port 53) + database port

## Telemetry

Hoppscotch collects anonymous usage data weekly (instance UUID, user count, workspace count, version). No API content or personal data is collected.

**To disable:** Admin Dashboard > Settings > Data Sharing

There is no environment variable to disable telemetry — it must be done via the Admin UI.

## Security Context

The chart enforces non-root execution and drops all capabilities:

```yaml
podSecurityContext:
  runAsNonRoot: true
  fsGroup: 1000

containerSecurityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  runAsNonRoot: true
  runAsUser: 1000
```

`readOnlyRootFilesystem` is set to `false` because Hoppscotch writes temporary files at runtime.
