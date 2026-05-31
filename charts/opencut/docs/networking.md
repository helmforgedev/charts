# Networking

The chart exposes OpenCut through a ClusterIP Service by default. Public access
is configured through Ingress or Gateway API.

## Service

The Service supports explicit IP family settings for dual-stack clusters:

```yaml
service:
  ipFamilyPolicy: PreferDualStack
  ipFamilies:
    - IPv4
    - IPv6
```

## Ingress

Use `ingress.ingressClassName` to match HelmForge chart conventions:

```yaml
ingress:
  enabled: true
  ingressClassName: traefik
  hosts:
    - host: opencut.example.com
      paths:
        - path: /
          pathType: Prefix
```

## Gateway API

`gateway.enabled` renders one `HTTPRoute`. `gateway.parentRefs` is required so
the chart never creates an orphaned route.

```yaml
gateway:
  enabled: true
  parentRefs:
    - name: public
  hostnames:
    - opencut.example.com
```

The chart does not install Gateway API CRDs or a Gateway controller.

<!-- @AI-METADATA
type: chart-docs
title: OpenCut Networking
description: Service, Ingress, and Gateway API configuration for OpenCut
keywords: opencut, networking, ingress, gateway-api, dual-stack
purpose: Explain OpenCut chart networking options
scope: Chart Operations
relations:
  - charts/opencut/README.md
  - charts/opencut/examples/gateway.yaml
path: charts/opencut/docs/networking.md
version: 1.0
date: 2026-05-29
-->
