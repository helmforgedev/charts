# External Secrets

The chart can render External Secrets Operator resources for credentials that should be sourced from an external provider.

## Admin Password

```yaml
admin:
  existingSecret: answer-admin

externalSecrets:
  enabled: true
  secretStoreRef:
    name: vault
    kind: SecretStore
  admin:
    enabled: true
    data:
      - secretKey: admin-password
        remoteRef:
          key: answer/admin
          property: password
```

## External Database Password

```yaml
database:
  external:
    vendor: postgres
    host: postgresql.example.com
    name: answer
    username: answer
    existingSecret: answer-db

externalSecrets:
  enabled: true
  secretStoreRef:
    name: vault
    kind: SecretStore
  database:
    enabled: true
    data:
      - secretKey: database-password
        remoteRef:
          key: answer/database
          property: password
```

## Backup S3 Credentials

```yaml
backup:
  s3:
    existingSecret: answer-backup

externalSecrets:
  enabled: true
  secretStoreRef:
    name: vault
    kind: SecretStore
  backup:
    enabled: true
    data:
      - secretKey: access-key
        remoteRef:
          key: answer/s3
          property: accessKey
      - secretKey: secret-key
        remoteRef:
          key: answer/s3
          property: secretKey
```

External Secrets Operator and provider-side SecretStores are outside this chart's scope.

<!-- @AI-METADATA
type: chart-docs
title: External Secrets
description: External Secrets Operator integration for Apache Answer credentials

keywords: answer, external-secrets, secretstore, credentials, admin, database, backup

purpose: Explain how to source Apache Answer credentials from External Secrets Operator
scope: Chart

relations:
  - charts/answer/README.md
  - charts/answer/values.yaml
path: charts/answer/docs/external-secrets.md
version: 1.0
date: 2026-06-02
-->
