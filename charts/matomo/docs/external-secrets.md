# External Secrets

The chart implements the HelmForge canonical `externalSecrets.items[]` contract.
Use it to project database passwords from Vault, AWS Secrets Manager, Google
Secret Manager, Azure Key Vault, or another external-secrets provider.

## Database Password

For an external database, set `database.external.existingSecret` to the target
secret name and render an ExternalSecret item that writes the same secret.

```yaml
mysql:
  enabled: false
database:
  mode: external
  external:
    host: mysql.prod.svc.cluster.local
    existingSecret: matomo-database
externalSecrets:
  enabled: true
  items:
    - fullnameOverride: matomo-database
      spec:
        secretStoreRef:
          name: prod-secrets
          kind: ClusterSecretStore
        target:
          name: matomo-database
          creationPolicy: Owner
        data:
          - secretKey: database-password
            remoteRef:
              key: prod/matomo/database
```

<!-- @AI-METADATA
type: chart-docs
title: Matomo External Secrets Guide
description: External Secrets integration for Matomo database credentials
keywords: matomo, external-secrets, vault, secrets
purpose: Explain secret projection patterns
scope: Chart
relations:
  - charts/matomo/templates/externalsecret.yaml
path: charts/matomo/docs/external-secrets.md
version: 1.0
date: 2026-07-06
-->
