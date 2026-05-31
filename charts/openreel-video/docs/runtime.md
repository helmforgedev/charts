# Runtime

OpenReel Video is served as static content from the HelmForge image.

## Container

The chart runs the container as a non-root user, drops Linux capabilities, uses
the runtime default seccomp profile, and keeps the root filesystem read-only.

`tmpVolume.enabled=true` mounts a small `emptyDir` at `/tmp` so NGINX can write
temporary files without requiring a writable image filesystem.

## Health

The image exposes `/healthz` for readiness, liveness, and Helm tests.

## ExternalName Mode

`service.type=ExternalName` is supported for migration or compatibility
scenarios where consumers expect the chart Service name but traffic should point
to another DNS name.

<!-- @AI-METADATA
type: chart-docs
title: OpenReel Video Runtime
description: Runtime and health behavior for OpenReel Video
keywords: openreel-video, runtime, nginx, health
purpose: Explain runtime assumptions and health checks
scope: Chart Operations
relations:
  - charts/openreel-video/DESIGN.md
path: charts/openreel-video/docs/runtime.md
version: 1.0
date: 2026-05-29
-->
