# Apache External Secrets

The chart can render an ExternalSecret for the Basic Auth htpasswd Secret.

```yaml
basicAuth:
  enabled: true
  existingSecret: apache-basicauth

externalSecrets:
  enabled: true
  secretStoreRef:
    name: cluster-secrets
    kind: ClusterSecretStore
  data:
    - secretKey: htpasswd
      remoteRef:
        key: apache/basicauth
        property: htpasswd
```

Use `dataFrom` when your provider can extract all required keys from a single
remote object:

```yaml
externalSecrets:
  enabled: true
  dataFrom:
    - extract:
        key: apache/basicauth
```

The chart fails rendering when ExternalSecret is enabled without `data` or
`dataFrom`.
