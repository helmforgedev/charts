# Networking

The Matomo chart supports both Kubernetes Ingress and Gateway API HTTPRoute.
Only the HTTP service is exposed; MySQL remains internal or external to the
chart depending on `database.mode`.

## Ingress

Set `ingress.enabled=true`, provide `ingress.hosts`, and optionally set
`ingress.ingressClassName`. The field is omitted when empty so the cluster
default IngressClass can apply.

## Gateway API

Set `gatewayAPI.enabled=true` and provide one or more `httpRoutes`. Each route
can supply `parentRefs`, `hostnames`, labels, annotations, and optional rules.
When rules do not specify a backend, the chart points the route to the Matomo
Service automatically.

## Dual-stack

Set `service.ipFamilyPolicy=PreferDualStack` to request dual-stack service
allocation without forcing explicit IP families. This keeps the values usable
on single-stack clusters.

## Container port

`containerPorts.http` sets the named web port used by probes, the Service, and
the NetworkPolicy. With `webServer.mode=apache`, the chart also configures the
real Apache listener and virtual host on that port. `service.port` remains an
independent client-facing Service port.

FPM images do not contain an HTTP listener. Set `webServer.mode=external` and
provide a web-server sidecar that listens on `containerPorts.http`; see
`ci/fpm-sidecar-values.yaml` for the maintained nginx example.

<!-- @AI-METADATA
type: chart-docs
title: Matomo Networking Guide
description: Ingress, Gateway API, and dual-stack networking for Matomo
keywords: matomo, ingress, gateway api, dual-stack
purpose: Explain network exposure options
scope: Chart
relations:
  - charts/matomo/values.yaml
path: charts/matomo/docs/networking.md
version: 1.1
date: 2026-10-28
-->
