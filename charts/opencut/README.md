# OpenCut Helm Chart

OpenCut is an open-source video editor. This HelmForge chart deploys the
OpenCut web application with PostgreSQL and Redis dependencies, plus a
Redis-over-HTTP bridge required by the upstream application runtime.

## Highlights

- HelmForge-maintained `docker.io/helmforge/opencut:v0.3.0` image.
- PostgreSQL and Redis subcharts for a turnkey install.
- `serverless-redis-http` bridge for `UPSTASH_REDIS_REST_*` compatibility.
- External Secrets Operator integration for external database credentials.
- Gateway API, Ingress, dual-stack Service support, HPA, PDB, NetworkPolicy,
  schema, and Helm tests.

## Install

```bash
helm install opencut oci://ghcr.io/helmforgedev/helm/opencut \
  --set opencut.siteUrl=https://opencut.example.com \
  --set opencut.betterAuthSecret="$(openssl rand -hex 32)"
```

## External Database

```yaml
postgresql:
  enabled: false

database:
  external:
    host: postgres.example.com
    name: opencut
    username: opencut
    existingSecret: opencut-db
    existingSecretPasswordKey: database-password
```

## External Secrets

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
  data:
    - secretKey: database-password
      remoteRef:
        key: opencut/database
        property: password
```

## Local Validation

```bash
helm dependency build charts/opencut
helm lint charts/opencut
helm template opencut charts/opencut -f charts/opencut/ci/ci-values.yaml
helm unittest charts/opencut
```
