# NoteDiscovery Authentication

Authentication is disabled by default for local bootstrap. Enable it for shared, team, or internet-facing deployments.

## Chart-Managed Secret

```yaml
auth:
  enabled: true
  secretKey: replace-with-a-long-random-secret
  password: replace-with-a-strong-password
  apiKey: ""
```

When `auth.enabled=true`, the chart stores the generated `config.yaml` in a Kubernetes Secret.

## Existing Secret

For production and GitOps, prefer an existing Secret containing a complete `config.yaml`:

```yaml
auth:
  existingSecret: notediscovery-config
  existingSecretKey: config.yaml
```

The Secret must contain every runtime setting that NoteDiscovery expects, not just authentication fields.

## External Secrets

When using External Secrets Operator, materialize the same complete config file into the Secret referenced by `auth.existingSecret`:

```yaml
auth:
  existingSecret: notediscovery-config

externalSecrets:
  enabled: true
  items:
    - name: config
      spec:
        secretStoreRef:
          kind: ClusterSecretStore
          name: production
        target:
          name: notediscovery-config
          creationPolicy: Owner
        data:
          - secretKey: config.yaml
            remoteRef:
              key: apps/notediscovery
              property: config.yaml
```
