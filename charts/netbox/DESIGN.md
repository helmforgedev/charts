# NetBox chart design

## Product model

NetBox is a Django application backed by PostgreSQL and Redis. Its web process
serves the UI, REST API, GraphQL API, and Prometheus endpoint. RQ workers run
scripts, data-source synchronization, and scheduled jobs. The housekeeping
management command removes expired sessions and retained records.

The chart preserves those boundaries rather than running unrelated processes
in one pod. A Service selects only `component=web`; worker and housekeeping
pods can never accidentally receive HTTP traffic.

## Image choice

The default `v4.6.5-5.0.2` tag combines an exact NetBox application release
with an exact netbox-docker support release. It is published for amd64 and
arm64. NetBox 4.6.7 existed when the chart was authored, but no matching exact
5.0.2 image was published, so the chart does not invent or use a moving tag.

## State

PostgreSQL is authoritative. Media is persistent and must be backed up with
the database. Redis database 0 is used for queues and database 1 for cache.
Reports, scripts, plugins, and configuration are supplied through an immutable
derived image or mounted configuration, not modified in the running image.

## Scaling

Web and RQ worker replicas scale independently. Multiple web replicas require
RWX media or an external storage backend; a template validation enforces the
PVC part of that contract. The chart does not imply that a standalone bundled
PostgreSQL or Redis instance is highly available.

## Security

The official container runs as UID 999 and GID 0. The chart drops Linux
capabilities, blocks privilege escalation, uses RuntimeDefault seccomp, and
does not mount API credentials. Copilot is disabled by default to prevent
implicit external AI traffic. Secrets support existing Kubernetes Secrets and
the canonical External Secrets resource surface.

## Upgrade boundary

The official entrypoint performs database migrations before starting the web
process. Operators must read both NetBox and netbox-docker release notes,
retain a database and media backup, and keep the two versions in the image tag
compatible. Plugin compatibility remains the operator's responsibility.

<!-- @AI-METADATA
type: design
title: NetBox chart design
description: Architecture and trade-offs for the HelmForge NetBox chart
keywords: netbox, architecture, state, scaling
purpose: Record durable chart design decisions
scope: Chart
relations:
  - charts/netbox/values.yaml
path: charts/netbox/DESIGN.md
version: 1.0
date: 2026-07-31
-->
