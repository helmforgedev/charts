# Production

OpenReel Video is stateless, but production deployments still need explicit
networking, resource, and security choices.

Use [examples/production.yaml](../examples/production.yaml) as a starting point.

## Baseline

- Configure HTTPS through Ingress or Gateway API.
- Keep `resources.requests` and `resources.limits` explicit.
- Use at least two replicas when running behind a production route.
- Enable `networkPolicy.enabled=true` after confirming traffic from the chosen
  ingress controller or Gateway implementation.
- Keep `tmpVolume.enabled=true` for non-root NGINX temporary files.

## Browser Isolation Headers

The HelmForge image includes COOP/COEP headers for browser APIs used by video
editing workflows. If an edge proxy rewrites headers, preserve the image
defaults or add equivalent headers at the proxy layer.

## Validation

```bash
helm test openreel-video -n openreel-video
kubectl get events -n openreel-video --sort-by=.lastTimestamp
kubectl logs -n openreel-video deploy/openreel-video --since=10m
```

<!-- @AI-METADATA
type: chart-docs
title: OpenReel Video Production
description: Production deployment guidance for the OpenReel Video Helm chart
keywords: openreel-video, production, webcodecs, ingress, gateway-api
purpose: Production hardening guide for OpenReel Video
scope: Chart Operations
relations:
  - charts/openreel-video/README.md
  - charts/openreel-video/examples/production.yaml
path: charts/openreel-video/docs/production.md
version: 1.0
date: 2026-05-29
-->
