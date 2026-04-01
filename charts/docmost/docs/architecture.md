# Docmost Architecture Notes

This chart packages Docmost as a single application Deployment backed by PostgreSQL and Redis. It is designed as an alpha chart with clear defaults, simple local validation, and explicit external-service support.

## Supported Model

- one Docmost application pod
- PostgreSQL provided by the bundled subchart or an external PostgreSQL service
- Redis provided by the bundled subchart or an external Redis service
- uploaded files stored on a local PVC or an S3-compatible object store

## Why Single Replica

This first chart release intentionally keeps `replicaCount=1`.

- upstream runtime documentation clearly requires PostgreSQL, Redis, and shared file storage
- local storage with multiple application replicas can create inconsistent file visibility unless operators provide shared external object storage and validate the runtime behavior carefully
- the alpha chart therefore favors predictable installs over premature horizontal-scaling claims

## Storage Modes

### Local Storage

- mounts `/app/data/storage` from a PVC
- good default for small single-instance installs
- easiest mode for local k3d validation

### S3-Compatible Storage

- sets `STORAGE_DRIVER=s3`
- uses `AWS_S3_*` environment variables documented by Docmost
- recommended when operators want object storage managed outside the pod filesystem

## External Services

You can disable the bundled `postgresql` and `redis` subcharts and point Docmost to managed services instead.

- use `database.mode=external` with `database.external.*`
- set `postgresql.enabled=false`
- set `redis.enabled=false`
- configure `redis.external.*`

## Version Pinning Note

At the time this chart was created, Docker Hub exposed `0.71.0` while the official GitHub releases page showed `v0.70.3` as the latest release. Following repository rules, the chart pins `0.70.3`, the latest version confirmed on both sources used for release validation.

<!-- @AI-METADATA
type: chart-docs
title: Docmost - Architecture Notes
description: Architecture and deployment notes for the Docmost Helm chart

keywords: docmost, architecture, postgresql, redis, s3, local-storage

purpose: Explain the supported Docmost deployment model and key architectural constraints
scope: Chart

relations:
  - charts/docmost/README.md
path: charts/docmost/docs/architecture.md
version: 1.0
date: 2026-04-01
-->
