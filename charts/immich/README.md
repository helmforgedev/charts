# Immich Helm Chart

Immich is a self-hosted photo and video management platform. This HelmForge
chart deploys Immich server, machine learning, Valkey, and the upstream
VectorChord PostgreSQL image recommended by Immich.

## Highlights

- Official Immich images pinned to `v2.7.5`.
- Internal PostgreSQL uses `ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0`.
- Internal Valkey uses `docker.io/valkey/valkey:9`.
- Machine learning service enabled by default with a model cache volume.
- External database and Redis/Valkey support with External Secrets Operator hooks.
- Gateway API, Ingress, dual-stack Service support, HPA, PDB, NetworkPolicy,
  schema, and Helm tests.

## Install

```bash
helm install immich oci://ghcr.io/helmforgedev/helm/immich
```

## Persistence

Persistent storage is enabled by default for uploads, PostgreSQL, Valkey, and
machine-learning model cache. For local smoke tests, disable persistence with
the k3d values file.

## External Database

```yaml
postgresql:
  enabled: false
database:
  external:
    host: postgres.example.com
    database: immich
    username: immich
    existingSecret: immich-db
    existingSecretPasswordKey: database-password
```
