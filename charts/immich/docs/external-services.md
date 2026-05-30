# External Services

Immich can consume platform-managed PostgreSQL and Redis/Valkey-compatible cache
services.

## External PostgreSQL

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgres.example.com
    port: 5432
    database: immich
    username: immich
    existingSecret: immich-db
    existingSecretPasswordKey: database-password
```

The database must include the extensions required by Immich before the
application starts.

## External Cache

```yaml
valkey:
  internal:
    enabled: false
  external:
    host: valkey.example.com
    port: 6379
    existingSecret: immich-cache
    existingSecretPasswordKey: redis-password
```

## External Secrets Operator

The chart can render `ExternalSecret` resources when the operator already
exists in the cluster. It does not install External Secrets Operator or create a
SecretStore.

<!-- @AI-METADATA
type: chart-docs
title: Immich External Services
description: External PostgreSQL and Redis/Valkey configuration for Immich
keywords: immich, postgresql, valkey, redis, external-secrets
purpose: Explain externally managed dependency configuration
scope: Chart Operations
relations:
  - charts/immich/DESIGN.md
  - charts/immich/examples/external-services.yaml
path: charts/immich/docs/external-services.md
version: 1.0
date: 2026-05-29
-->
