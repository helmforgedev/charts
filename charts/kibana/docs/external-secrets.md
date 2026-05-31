# Kibana External Secrets

The chart can render an ExternalSecret for Elasticsearch credentials and Kibana
encryption keys.

```yaml
elasticsearch:
  auth:
    type: serviceAccountToken

externalSecrets:
  enabled: true
  secretStoreRef:
    name: cluster-secrets
    kind: ClusterSecretStore
  data:
    - secretKey: service-account-token
      remoteRef:
        key: elastic/kibana
        property: service-account-token
    - secretKey: xpack-security-encryption-key
      remoteRef:
        key: elastic/kibana
        property: security-key
```

Use `dataFrom` when the remote secret contains all expected keys:

```yaml
externalSecrets:
  enabled: true
  dataFrom:
    - extract:
        key: elastic/kibana
```

The chart fails rendering when ExternalSecret is enabled without `data` or
`dataFrom`.
