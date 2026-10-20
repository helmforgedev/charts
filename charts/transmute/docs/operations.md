# Transmute Operations Guide

This operational guide provides deployment procedures, authentication integrations,
storage administration, and troubleshooting patterns for Transmute on Kubernetes.

## Architecture Overview

Transmute runs as a stateful video/audio processing service. The container executes
as non-root (UID/GID 1000) and mounts persistent storage at `/app/data`.

## Deployment Methods

### Basic Installation

Add the repository and install the release:

```bash
helm repo add helmforge https://repo.helmforge.dev
helm repo update
helm install transmute helmforge/transmute --namespace media --create-namespace
```

### Production Deployment with Ingress and TLS

```yaml
service:
  type: ClusterIP
  port: 8080

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: transmute.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: transmute-tls
      hosts:
        - transmute.example.com

persistence:
  enabled: true
  size: 50Gi
  storageClass: fast-storage
```

## Authentication

### Managed Credentials vs Pre-existing Secrets

By default, the chart provisions a Kubernetes Secret holding the initial admin password
and application secret key. To use an externally managed secret:

```yaml
auth:
  existingSecret: "transmute-auth-secrets"
```

### External Secrets Operator (ESO)

To fetch secrets directly from Vault, AWS Secrets Manager, or Azure Key Vault:

```yaml
externalSecrets:
  enabled: true
  secretStoreRef:
    name: vault-cluster-store
    kind: ClusterSecretStore
  data:
    - secretKey: admin-password
      remoteRef:
        key: secret/data/transmute
        property: password
    - secretKey: secret-key
      remoteRef:
        key: secret/data/transmute
        property: secret_key
```

### OpenID Connect (OIDC) Single Sign-On

Integrate with identity providers such as Keycloak, Authentik, or Okta:

```yaml
oidc:
  enabled: true
  providerUrl: "https://auth.example.com/realms/master"
  clientId: "transmute-client"
  clientSecret: "my-client-secret-token"
  redirectUri: "https://transmute.example.com/api/auth/oidc/callback"
```

## Backup and Disaster Recovery

All queues, user databases, and scratch data live in `/app/data`:

1. Snapshot-based Backup: Snapshot the PersistentVolumeClaim during quiet periods.
2. File-level Backup: Run a volume backup utility (such as Velero) pointing to the PVC.

## Troubleshooting

### Check Pod Health

```bash
kubectl get pods -n media -l app.kubernetes.io/name=transmute
kubectl describe pod -n media -l app.kubernetes.io/name=transmute
```

### View Application Logs

```bash
kubectl logs -n media -l app.kubernetes.io/name=transmute -f --tail=100
```

### Common Issues

- Transcoding job hangs or OOMKilled: Transcoding large high-bitrate video consumes significant RAM. Increase `resources.limits.memory` in `values.yaml`.
- Persistent storage permissions: The container runs under UID 1000. Ensure the storage provisioner sets correct filesystem ownership or `securityContext.fsGroup: 1000`.
