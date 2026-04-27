# Generic Chart Gateway API

## HTTPRoute

`gatewayApi.enabled` renders Gateway API `HTTPRoute` resources from `gatewayApi.httpRoutes[]`. The chart does not install Gateway API CRDs or a Gateway controller.

```yaml
gatewayApi:
  enabled: true
  httpRoutes:
    - name: web
      parentRefs:
        - name: public
      hostnames:
        - app.example.com
      rules:
        - matches:
            - path:
                type: PathPrefix
                value: /
```

If a route rule omits `backendRefs`, it points at the primary Service using `service.port`. Use custom `backendRefs` for multi-service routing.

<!-- @AI-METADATA
type: chart-docs
title: Generic Chart - Gateway API
description: HTTPRoute support for the generic chart
keywords: generic, gateway-api, httproute
purpose: Gateway API guide for the generic chart
scope: Chart Architecture
relations:
  - charts/generic/README.md
path: charts/generic/docs/gateway.md
version: 1.0
date: 2026-04-27
-->

