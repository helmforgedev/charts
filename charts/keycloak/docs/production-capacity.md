# Production Capacity

## When to use this guide

Read this guide before choosing CPU, memory, and scheduling priority for a production Keycloak deployment.

## Current chart model

The chart leaves container sizing under operator control through either explicit `resources` or an optional `capacity.profile`.

Default behavior:

- if `resources` is not set, the chart renders with `resources: {}`
- `capacity.profile` defaults to `custom`
- no CPU or memory requests/limits are imposed by default

This keeps capacity decisions aligned with the real platform and workload instead of hiding them behind presets.

## Capacity profiles

Use `capacity.profile` only as a starting point:

```yaml
capacity:
  profile: medium
```

Profiles are conservative presets:

| Profile | Requests | Limits |
|---------|----------|--------|
| `small` | `500m`, `1Gi` | `1`, `2Gi` |
| `medium` | `1`, `2Gi` | `2`, `4Gi` |
| `large` | `2`, `3Gi` | `4`, `6Gi` |

Do not combine `capacity.profile` with explicit `resources`. If you need exact values, keep `capacity.profile: custom` and set `resources`.

## Priority class

The chart already exposes `priorityClassName`.

Use it when:

- Keycloak is part of a platform control surface
- the cluster has eviction pressure
- the platform already defines workload priorities

Do not set a high-priority class casually. Priority must be aligned with the rest of the platform.

## Recommended baseline

For a serious production environment, a reasonable starting point is:

```yaml
capacity:
  profile: medium
priorityClassName: platform-critical
```

If the platform does not define a suitable priority class, leave `priorityClassName` empty and rely on normal scheduling policy.

## Heavy startup profile

If the deployment uses a larger provider or theme footprint, combine capacity planning with:

```yaml
probes:
  profile: heavy-startup
```

This gives the pod more time to bootstrap before startup and readiness failures begin to matter.

## Final recommendation

- start with explicit `resources` based on expected concurrency and extension footprint
- refine those values with real production telemetry
- keep `priorityClassName` aligned with cluster policy, not with guesswork

<!-- @AI-METADATA
type: chart-docs
title: Keycloak - Production Capacity
description: Resource sizing and capacity

keywords: keycloak, production, resources, sizing

purpose: Resource sizing and capacity planning for Keycloak production deployments
scope: Chart Architecture

relations:
  - charts/keycloak/docs/production.md
  - charts/keycloak/docs/scaling-and-clustering.md
path: charts/keycloak/docs/production-capacity.md
version: 1.0
date: 2026-03-20
-->
