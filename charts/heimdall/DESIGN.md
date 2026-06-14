# Heimdall Chart Design

## Purpose

This chart deploys Heimdall as a lightweight application dashboard for
self-hosted services. Heimdall stores its application links, settings, and
SQLite data under `/config`, so the chart is intentionally modeled as a
single-replica workload with persistent storage and optional S3 backup.

## Workload Model

The runtime workload is one Deployment running the official
`docker.io/linuxserver/heimdall` image. The container exposes HTTP on port 80
and receives LinuxServer-style environment variables:

- `PUID` controls the numeric user ID used for file ownership.
- `PGID` controls the numeric group ID used for file ownership.
- `TZ` controls the application timezone.

When persistence is enabled, the Deployment uses `strategy.type: Recreate`.
This avoids running two pods against the same SQLite-backed `/config` data
during rolling updates.

## Storage Strategy

Heimdall stores mutable state in `/config`. The chart creates a PVC by default
and mounts it at `/config`. Operators can disable persistence for disposable
tests or provide `persistence.existingClaim` when storage is managed outside the
release.

Because the application is SQLite-backed, the chart does not expose replica
configuration. Running multiple replicas against the same PVC is not supported.

## Networking

The Service exposes the application HTTP port through `service.port`.
Ingress is optional and supports Kubernetes networking.k8s.io/v1 hosts, paths,
class name, annotations, and TLS entries. TLS is modeled as an explicit list so
operators can use cert-manager, pre-created Secrets, or HTTP-only ingress.

## Backup Strategy

When `backup.enabled` is true, the chart creates a CronJob that mounts the same
configuration PVC read-only, creates a compressed tar archive of `/config`, and
uploads the archive to an S3-compatible endpoint with the HelmForge `mc` image.

The backup job supports:

- Inline credentials for test environments.
- `backup.s3.existingSecret` for production-managed credentials.
- Optional bucket creation.
- A configurable archive prefix and S3 object prefix.

Backups capture Heimdall configuration and SQLite state only. They do not back
up target applications linked from the dashboard.

## Security Posture

The chart uses a pinned LinuxServer Heimdall image and keeps pod and container
security contexts operator-configurable. This is important because LinuxServer
images use PUID/PGID-based file ownership and storage backends vary across
clusters. Production installs should set resource requests and limits, provide
an explicit security context compatible with the storage driver, and apply
NetworkPolicy outside this chart when the cluster supports it.

## Validation Coverage

The CI values cover:

- Default persistent deployment.
- Persistence disabled.
- Ingress with TLS.
- S3 backup rendering with an existing credentials Secret.

Full validation for chart changes must use `make validate-chart CHART=heimdall`.

<!-- @AI-METADATA
type: chart-design
title: Heimdall Chart Design
description: Architecture and operational design for the Heimdall HelmForge chart
keywords: heimdall, dashboard, sqlite, persistence, backup, ingress
purpose: Explain workload, storage, networking, backup, and validation design
scope: Chart
relations:
  - charts/heimdall/Chart.yaml
  - charts/heimdall/values.yaml
  - charts/heimdall/templates/deployment.yaml
  - charts/heimdall/templates/backup-cronjob.yaml
path: charts/heimdall/DESIGN.md
version: 1.0
date: 2026-06-14
-->
