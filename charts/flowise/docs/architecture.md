# Flowise Architecture Notes

## Modes

The Flowise chart supports two product-oriented modes:

- `standalone`: a simpler topology for local persistence and SQLite-backed installs
- `queue`: a scalable topology with main servers, worker deployments, Redis, and SQL storage

## Standalone Mode

Standalone mode is the default. It is optimized for the smallest useful install:

- `database.mode` resolves to `sqlite` unless PostgreSQL or an external database is configured
- `storage.type=local` stores uploaded files inside the Flowise data volume
- `persistence.enabled=true` creates a PVC mounted at `/root/.flowise`

This is the most practical way to get Flowise running on a small cluster or lab environment.

## Queue Mode

Flowise upstream recommends queue mode for production-scale deployments. In this chart:

- the main deployment serves the UI and API
- a separate worker deployment runs `flowise worker`
- Redis is mandatory
- the database must resolve to PostgreSQL or an external SQL database
- S3-compatible object storage is mandatory for shared blob storage across pods

Because queue mode is intended for shared-nothing horizontal scaling, this chart explicitly rejects:

- SQLite in queue mode
- local blob storage in queue mode
- persistent local app volumes in queue mode

## Database Guidance

### SQLite

Use SQLite only for standalone mode. It is simple and useful for local or small installs, but it is not a valid clustered backend for multiple Flowise pods.

### PostgreSQL

PostgreSQL is the recommended database for queue mode and larger deployments. The chart supports:

- bundled PostgreSQL via `postgresql.enabled=true`
- external PostgreSQL via `database.mode=external` and `database.external.vendor=postgres`

### MySQL

The chart also supports external MySQL by setting:

```yaml
database:
  mode: external
  external:
    vendor: mysql
```

## Storage Guidance

### Local

Use local storage for standalone mode when a PVC is acceptable and you are not scaling across pods.

### S3

Use S3-compatible storage for queue mode and any scenario where uploads or generated artifacts must be shared across multiple pods.

The chart accepts standard S3 settings:

- bucket name
- access key
- secret key
- region
- custom endpoint
- path-style toggle for MinIO and similar providers

## Health Checks

The main Flowise deployment uses the upstream HTTP endpoint:

- `/api/v1/ping`

This matches the official Docker Compose healthcheck pattern from the upstream project.

<!-- @AI-METADATA
type: chart-docs
title: Flowise Architecture Notes
description: Supported deployment modes, scaling constraints, and storage guidance for the Flowise Helm chart

keywords: flowise, architecture, queue, standalone, redis, postgresql, sqlite, s3

purpose: Explain supported Flowise topologies and operational constraints for chart users
scope: Chart

relations:
  - charts/flowise/README.md
path: charts/flowise/docs/architecture.md
version: 1.0
date: 2026-03-31
-->
