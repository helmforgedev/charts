# OpenCut Chart Design

## Scope

This chart deploys OpenCut as a Helm-native web application with the supporting
services OpenCut expects at runtime.

Supported dependency modes:

- bundled HelmForge PostgreSQL and Redis subcharts for turnkey installs
- external PostgreSQL and external Redis for platform-managed data services
- Redis-over-HTTP bridge for OpenCut `UPSTASH_REDIS_REST_*` compatibility
- external Redis REST endpoint for platforms that already provide an
  Upstash-compatible API

The chart intentionally avoids installing platform controllers such as Ingress,
Gateway API, External Secrets Operator, storage provisioners, or monitoring
stacks.

## Architecture: Bundled Dependencies

```mermaid
flowchart TB
  browser[Browser] --> route[Ingress or HTTPRoute]
  route --> web[OpenCut Deployment]
  web --> pgsvc[PostgreSQL Service]
  pgsvc --> pg[HelmForge PostgreSQL StatefulSet]
  pg --> pgpvc[(PostgreSQL PVC)]
  web --> redisHttp[Redis HTTP bridge]
  redisHttp --> redissvc[Redis Service]
  redissvc --> redis[HelmForge Redis StatefulSet]
  redis --> redispvc[(Redis PVC)]
  web --> secret[OpenCut app Secret]
```

Bundled mode is appropriate for local environments, preview environments, and
small installations where the release should own the complete runtime.

## Architecture: Platform Services

```mermaid
flowchart TB
  browser[Browser] --> route[Ingress or HTTPRoute]
  route --> web[OpenCut Deployment]
  web --> pg[(External PostgreSQL)]
  web --> redisHttp[Redis HTTP bridge]
  redisHttp --> redis[(External Redis)]
  eso[External Secrets Operator optional] -. materializes .-> secret[Database or Redis Secret]
  web --> secret
```

Platform-service mode is preferred when database backup, restore, patching, and
credential ownership are managed outside the release.

## Main Design Choices

- Use a HelmForge-maintained OpenCut image so the chart can pin a reproducible
  runtime and publish SBOM/signing evidence with the HelmForge release process.
- Use HelmForge PostgreSQL and Redis subcharts instead of third-party
  dependencies so database behavior, guardrails, and values remain consistent.
- Keep the Redis HTTP bridge explicit because the upstream application consumes
  HTTP-style Redis environment variables.
- Fail fast when the bridge is disabled without an external Redis REST URL and
  token source, because OpenCut requires both `UPSTASH_REDIS_REST_URL` and
  `UPSTASH_REDIS_REST_TOKEN` at startup.
- Use a single `gateway` values block for Gateway API HTTPRoute support.
- Derive `opencut.siteUrl` from Ingress or Gateway hostnames only when the user
  does not set it directly.
- Keep application credentials in Secrets and support External Secrets for
  externally owned PostgreSQL credentials.

## Explicit Non-Goals

- video transcoding workers outside the upstream OpenCut web runtime
- bundled object storage
- installing Gateway API CRDs, Ingress controllers, or External Secrets Operator
- managing external PostgreSQL or Redis lifecycle
- automatic database migrations outside the OpenCut application startup path

## Production Boundary

Production users should provide explicit values for:

- `opencut.siteUrl`
- `opencut.betterAuthSecret`
- PostgreSQL and Redis credentials through existing Secrets or External Secrets
- persistence sizes and storage classes
- CPU and memory resources
- `networkPolicy.enabled=true`
- TLS through Ingress or Gateway infrastructure

## Security Boundary

The OpenCut and Redis HTTP Deployments run as non-root, use the runtime-default
seccomp profile, drop all Linux capabilities, disable privilege escalation,
use read-only root filesystems, and do not receive service account tokens.
Writable application and temporary paths are backed by `emptyDir` volumes.

Kubernetes Secrets contain the Better Auth secret, Redis REST token, and any
inline external-service credentials. Production installations should reference
pre-existing Secrets or External Secrets instead of storing credentials in
values. When enabled, NetworkPolicy admits web traffic only on the configured
OpenCut listener and permits the bridge only from OpenCut web pods on its
configured listener.

## Observability Boundary

Startup, readiness, and liveness probes cover both the OpenCut HTTP endpoint
and Redis HTTP bridge. Kubernetes events, pod restart counts, and container
logs are the primary operational signals. The chart does not create a
ServiceMonitor or logging stack because neither runtime exposes a supported
Prometheus endpoint in this integration. Operators own cluster-level metrics,
log collection, dashboards, and alerting.

## Known Gaps

- OpenCut does not expose a chart-supported Prometheus metrics endpoint.
- The chart validates HTTP health and dependency connectivity but cannot
  automate browser editing or video export inside the release lifecycle.
- The bundled Redis HTTP bridge is a single replica and should be replaced by
  a platform-managed Upstash-compatible service when higher availability is
  required.
- Backup and restore lifecycle management remains the operator's responsibility.

<!-- @AI-METADATA
type: design
title: OpenCut Chart Design
description: Design document for the OpenCut Helm chart architecture, dependency modes, and production boundaries
keywords: opencut, design, architecture, postgresql, redis, gateway-api
purpose: Document chart design choices and operational boundaries
scope: Chart Design
relations:
  - charts/opencut/README.md
  - charts/opencut/docs/production.md
  - charts/opencut/docs/external-services.md
path: charts/opencut/DESIGN.md
version: 1.0
date: 2026-05-29
-->
