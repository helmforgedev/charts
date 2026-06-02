# Ghost Database Modes

## Bundled MySQL

The default configuration deploys Ghost with the HelmForge MySQL dependency:

```yaml
mysql:
  enabled: true
  auth:
    database: ghost
    username: ghost
```

This mode is useful for self-contained deployments and local validation. Size the MySQL PVC explicitly for real sites.

## External MySQL

Use an external database when MySQL is managed by your platform or cloud provider:

```yaml
mysql:
  enabled: false

database:
  external:
    host: mysql.example.com
    port: "3306"
    name: ghost
    username: ghost
    existingSecret: ghost-db
    existingSecretPasswordKey: password
```

The referenced Secret must contain the database password key.

## External Secrets

When using External Secrets, set `database.external.existingSecret` to the target Secret name. This prevents the
chart-managed database Secret and the ExternalSecret from drifting.

```yaml
mysql:
  enabled: false

database:
  external:
    host: mysql.example.com
    existingSecret: ghost-db

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  data:
    - secretKey: password
      remoteRef:
        key: ghost/database
        property: password
```

## Notes

- Ghost production mode requires MySQL.
- SQLite is only a development-mode option in the official image and is intentionally not part of this chart contract.
- Back up both the database and `/var/lib/ghost/content` before upgrades.

<!-- @AI-METADATA
type: chart-doc
title: Ghost Database Modes
description: Database mode guide for the Ghost Helm chart

keywords: ghost, mysql, database, external-secrets, backup, helm, kubernetes

purpose: Explain bundled MySQL, external database, and External Secrets usage
scope: Chart Documentation

relations:
  - charts/ghost/README.md
  - charts/ghost/DESIGN.md
path: charts/ghost/docs/database.md
version: 1.0
date: 2026-06-02
-->
