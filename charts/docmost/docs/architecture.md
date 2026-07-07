# Docmost Architecture Notes

This chart packages Docmost as an application Deployment backed by PostgreSQL and Redis. It is designed
with clear defaults, local validation, explicit external-service support, and optional S3-compatible object storage.

## Supported Model

- one Docmost application pod with local storage, or multiple application pods with S3-compatible storage
- PostgreSQL provided by the bundled subchart or an external PostgreSQL service
- Redis provided by the bundled subchart or an external Redis service
- uploaded files stored on a local PVC or an S3-compatible object store
- HTTP exposed through a ClusterIP Service, optional Ingress, or optional Gateway API HTTPRoute
- optional External Secrets Operator integration for credentials managed outside Helm
- optional PostgreSQL backup CronJob that uploads dumps to S3-compatible storage

## Replica Model

The chart defaults to `replicaCount=1` and keeps local storage single-replica.

- upstream runtime documentation clearly requires PostgreSQL, Redis, and shared file storage
- local storage with multiple application replicas can create inconsistent file visibility
- values greater than one are accepted only with `storage.mode=s3`, where uploaded files are stored outside the pod filesystem

## Storage Modes

### Local Storage

- mounts `/app/data/storage` from a PVC
- good default for small single-instance installs
- easiest mode for local k3d validation

### S3-Compatible Storage

- sets `STORAGE_DRIVER=s3`
- uses `AWS_S3_*` environment variables documented by Docmost
- required when operators set `replicaCount` greater than `1`

## External Services

You can disable the bundled `postgresql` and `redis` subcharts and point Docmost to managed services instead.

- use `database.mode=external` with `database.external.*`
- set `postgresql.enabled=false`
- set `redis.enabled=false`
- configure `redis.external.*`

## Network Exposure

The chart always renders an internal HTTP Service. Operators can add one of the supported north-south routing options:

- `ingress.enabled=true` for standard Kubernetes Ingress controllers
- `gateway.enabled=true` for Gateway API HTTPRoute
- `service.ipFamilyPolicy` and `service.ipFamilies` for explicit single-stack or dual-stack Service behavior

## Database Bootstrap

The bundled PostgreSQL configuration initializes the Docmost database with required privileges and extensions on first boot.
The bootstrap script uses the configured `postgresql.auth.database` and `postgresql.auth.username` values, so renamed databases
and users are supported without editing SQL manually.

## Version Pinning Note

The chart pins the upstream application image through `image.tag` and `appVersion`. For this release, `docmost/docmost:0.95.0` was verified as available on Docker Hub before updating the chart.

## Telemetry

Docmost supports disabling anonymous upstream telemetry through the `DISABLE_TELEMETRY` environment variable. The chart exposes
this as `docmost.disableTelemetry` so operators can opt out without overriding the raw container environment list.

<!-- @AI-METADATA
type: chart-docs
title: Docmost - Architecture Notes
description: Architecture and deployment notes for the Docmost Helm chart

keywords: docmost, architecture, postgresql, redis, s3, local-storage, gateway-api, external-secrets, dual-stack, backup

purpose: Explain the supported Docmost deployment model and key architectural constraints
scope: Chart

relations:
  - charts/docmost/README.md
path: charts/docmost/docs/architecture.md
version: 1.0
date: 2026-05-05
-->
