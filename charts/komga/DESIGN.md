# Komga Chart Design

## Scope

This chart deploys Komga as a single-instance media server for comics, manga,
magazines, and ebooks. It uses the official `gotson/komga` image, SQLite-backed
application state on `/config`, a separate library volume on `/data`, and
optional HTTP exposure through Ingress or Gateway API.

The chart is intentionally focused on the Komga application and the Kubernetes
resources needed to run it predictably. It does not install external databases,
object storage, authentication proxies, media indexers, or backup storage
services.

## Architecture

```mermaid
flowchart LR
  users[Readers and admins] --> service[Komga Service]
  ingress[Ingress optional] --> service
  route[HTTPRoute optional] --> service
  service --> deploy[Komga Deployment]
  deploy --> config[(Config PVC /config)]
  deploy --> data[(Library PVC /data)]
  cron[Backup CronJob optional] --> config
  cron --> s3[S3-compatible bucket]
  eso[ExternalSecret optional] --> secret[S3 credentials Secret]
  secret --> cron
```

The workload is a single Deployment with one replica because Komga stores its
application database in SQLite. The chart separates `/config` and `/data` so the
database/config volume can be backed up independently from large media files.

## Main Design Choices

- Use the official upstream `gotson/komga` image pinned to the chart appVersion.
- Keep SQLite as the default and only database mode.
- Persist both `/config` and `/data` by default.
- Keep the service internal by default, with explicit opt-in for Ingress or
  Gateway API.
- Expose JVM tuning through `komga.javaToolOptions` without forcing a memory
  profile on small installs.
- Provide an optional S3 backup CronJob for consistent SQLite exports and config
  archives.
- Support External Secrets Operator for S3 backup credentials without making ESO
  a chart dependency.

## Production Boundary

Production deployments should keep persistence enabled, size the `/data` PVC for
the media library, configure `komga.javaToolOptions` for the available memory,
set explicit resource requests and limits, and use Ingress or Gateway API only
with TLS termination handled by the cluster ingress layer.

Backups cover SQLite database files and top-level application configuration from
`/config`. They intentionally exclude library media under `/data`; media backup
or replication belongs to the storage platform or a separate backup workflow.

## Security Boundary

The default workload and backup Pods disable Kubernetes API token mounts, use
the runtime-default seccomp profile, and prevent privilege escalation. These
controls are compatible with the official image's current root entry point and
with files created by earlier chart releases.

The chart deliberately does not change the default UID, GID, or root filesystem
mode. Existing SQLite files may be root-owned, and Komga's SQLite JDBC native
library cannot start with a read-only image filesystem. Operators may set
`podSecurityContext` and `securityContext` after verifying ownership and write
access on both PVCs. Capabilities are not dropped by default because root must
retain discretionary access to installations that previously wrote restrictive
files with a custom UID; changing this would break those upgrades. TLS
termination, network policy enforcement, Secret access, container-image
admission, and storage encryption remain platform concerns.

## Observability Boundary

Kubernetes startup, readiness, and liveness probes cover process availability.
Application and backup logs are available through the cluster logging path, and
the backup CronJob exposes completion through Job status and events. The chart
does not create a ServiceMonitor because Komga does not provide a stable native
Prometheus endpoint. Alerting, log retention, backup-object monitoring, and
synthetic reader checks belong to the platform monitoring stack.

## Current Gaps and Improvement Candidates

- Add first-class NetworkPolicy support for web traffic and backup egress.
- Add an optional PodDisruptionBudget if the chart grows beyond a single
  replica model.
- Revisit a non-root default if upstream publishes an explicit user and a
  migration path for root-owned SQLite files.
- Add documented restore smoke tests for the backup workflow.
- Add optional ServiceMonitor support if Komga exposes stable application
  metrics in a future release.

## Explicit Non-Goals

- running multiple Komga replicas against the same SQLite database
- external database automation
- bundled object storage
- bundled authentication proxy or SSO gateway
- media file backup for `/data`
- installing External Secrets Operator, Gateway API CRDs, or cert-manager

<!-- @AI-METADATA
type: design
title: Komga Chart Design
description: Design document for the Komga Helm chart
keywords: komga, comics, manga, sqlite, media-server, backup
purpose: Document chart architecture, decisions, production boundaries, and non-goals
scope: Chart Design
relations:
  - charts/komga/README.md
  - charts/komga/docs/backup.md
  - charts/komga/examples/production/values.yaml
path: charts/komga/DESIGN.md
version: 1.0
date: 2026-06-14
-->
