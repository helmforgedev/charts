# External Services

OpenCut can consume platform-managed PostgreSQL and Redis instead of the bundled
HelmForge subcharts.

## External PostgreSQL

Disable the PostgreSQL subchart and provide the connection details:

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgres.example.com
    port: 5432
    name: opencut
    username: opencut
    existingSecret: opencut-db
    existingSecretPasswordKey: database-password
```

The target database and user must exist before OpenCut starts.

## External Redis

Disable the Redis subchart and point the Redis HTTP bridge at an external Redis
endpoint:

```yaml
redis:
  enabled: false
  external:
    host: redis.example.com
    port: 6379
    existingSecret: opencut-redis
    existingSecretPasswordKey: redis-password
```

`redisHttp.enabled` should remain enabled unless OpenCut can reach another
Redis REST-compatible endpoint directly. When disabling the in-cluster bridge,
provide the required `UPSTASH_REDIS_REST_*` settings through
`redisHttp.external`:

```yaml
redis:
  enabled: false

redisHttp:
  enabled: false
  external:
    url: https://redis-rest.example.com
    existingSecret: opencut-redis-rest
    existingSecretTokenKey: redis-rest-token
```

## External Secrets Operator

For externally managed PostgreSQL credentials:

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgres.example.com
    existingSecret: opencut-db
    existingSecretPasswordKey: database-password

externalSecrets:
  enabled: true
  secretStoreRef:
    name: platform-secrets
    kind: ClusterSecretStore
  data:
    - secretKey: database-password
      remoteRef:
        key: opencut/database
        property: password
```

The chart does not create the `SecretStore` or install External Secrets
Operator.

<!-- @AI-METADATA
type: chart-docs
title: OpenCut External Services
description: External PostgreSQL, Redis, and External Secrets configuration for OpenCut
keywords: opencut, postgresql, redis, external-secrets
purpose: Explain externally managed dependency configuration
scope: Chart Operations
relations:
  - charts/opencut/DESIGN.md
  - charts/opencut/examples/external-services.yaml
path: charts/opencut/docs/external-services.md
version: 1.0
date: 2026-05-29
-->
