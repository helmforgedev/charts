<!-- SPDX-License-Identifier: Apache-2.0 -->

# External Secrets

External Secrets Operator is installed and administered outside this chart. The
chart implements the canonical `externalSecrets.items[]` contract and hardcodes
`external-secrets.io/v1`.

```yaml
discourse:
  existingSecret: discourse-credentials

externalSecrets:
  enabled: true
  items:
    - fullnameOverride: discourse-credentials
      spec:
        secretStoreRef:
          name: production-secrets
          kind: ClusterSecretStore
        target:
          name: discourse-credentials
          creationPolicy: Owner
        data:
          - secretKey: secret-key-base
            remoteRef:
              key: production/discourse
              property: secret-key-base
```

The secret key base must be a stable 128-character hexadecimal string. Database
and Redis items follow the same pattern and target the names configured under
`database.external.existingSecret` and `redis.external.existingSecret`.

Verify reconciliation before diagnosing the application:

```bash
kubectl get externalsecret,secret -n NAMESPACE
kubectl wait externalsecret/NAME -n NAMESPACE \
  --for=condition=Ready=True --timeout=60s
```
