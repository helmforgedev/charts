# External Secrets

The chart implements the HelmForge canonical `externalSecrets.items[]` contract.
Use it to source the ClickHouse password from an external secret manager.

```yaml
clickhouse:
  existingSecret: clickhouse-auth
externalSecrets:
  enabled: true
  items:
    - fullnameOverride: clickhouse-auth
      spec:
        secretStoreRef:
          name: prod-secrets
          kind: ClusterSecretStore
        target:
          name: clickhouse-auth
          creationPolicy: Owner
        data:
          - secretKey: clickhouse-password
            remoteRef:
              key: prod/clickhouse/password
```

The official image reads `CLICKHOUSE_PASSWORD` only during first initialization
of an empty data directory. Rotate passwords with SQL once a data volume already
exists.

<!-- @AI-METADATA
type: chart-docs
title: ClickHouse External Secrets Guide
description: External Secrets integration for ClickHouse credentials
keywords: clickhouse, external-secrets, credentials
purpose: Explain secret projection
scope: Chart
relations:
  - charts/clickhouse/templates/externalsecret.yaml
path: charts/clickhouse/docs/external-secrets.md
version: 1.0
date: 2026-07-06
-->
