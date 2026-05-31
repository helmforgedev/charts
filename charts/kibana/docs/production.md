# Kibana Production Guide

Use production deployments with explicit Elasticsearch authentication, TLS, and
stable encryption keys.

```yaml
replicaCount: 2

elasticsearch:
  hosts:
    - https://elasticsearch:9200
  auth:
    type: serviceAccountToken
    existingSecret: kibana-elasticsearch-token
  tls:
    enabled: true
    certificateAuthoritiesSecret: elasticsearch-ca
    verificationMode: certificate

encryptionKeys:
  existingSecret: kibana-encryption-keys

networkPolicy:
  enabled: true
```

## Encryption Keys

Kibana uses encryption keys for sessions, reporting, and encrypted saved
objects. Multi-replica deployments must use stable keys through
`encryptionKeys.existingSecret` or static values.

## Authentication

Use `serviceAccountToken` for Elastic Stack service account authentication when
available. Basic auth is also supported for environments that still use the
`kibana_system` user.

## Operations

After deployment:

```bash
helm test kibana -n observability
kubectl get pods -n observability -l app.kubernetes.io/name=kibana
kubectl logs -n observability deploy/kibana
```
