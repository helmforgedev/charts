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

The official image rewrites the chart-configured user in
`users.d/default-user.xml` on every container start. To rotate that password,
update the external value, wait for the Kubernetes Secret to refresh, and
restart the StatefulSet. Test authentication after the restart. Users managed
separately through SQL retain their own lifecycle.

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
