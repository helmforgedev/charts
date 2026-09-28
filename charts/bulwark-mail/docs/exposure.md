<!-- markdownlint-disable MD013 -->

# Exposure, Gateway API, and CORS

## Root-path requirement

The published Bulwark image bakes the base path during its build. This chart accepts only `/`. Rewriting `/webmail` at a proxy does not rewrite emitted assets and is rejected during template validation.

## Ingress

Use `ingress.ingressClassName`; the chart does not assume a controller. Terminate TLS at the ingress and route the root path to service port 3000.

## Gateway API

`gatewayAPI.httpRoutes[]` creates one HTTPRoute per item. Supply `parentRefs`. When an item omits `rules`, the chart creates a root-path rule pointing at its Service. When `rules` is present, it is rendered exactly as supplied and the chart does not inject a backend. Install Gateway API CRDs and a controller separately.

Ingress and Gateway API cannot both be enabled for one release.

## JMAP reachability

Bulwark returns the JMAP URL to the browser. It must therefore be resolvable and trusted from outside the cluster. Prefer a public HTTPS name.

When Bulwark and Stalwart have different origins, Stalwart or its proxy must emit an exact `Access-Control-Allow-Origin` for Bulwark and `Access-Control-Allow-Credentials: true`. Wildcard origins cannot be used with credentials.

## Same-origin topology

A same-origin layout can avoid CORS, but both services must still live at paths supported by their images. Because the published Bulwark image supports `/`, place Bulwark at the host root or build a custom image with the desired base path.

## Troubleshooting

- UI loads but sign-in reports unreachable server: inspect browser network errors and DNS, not just pod connectivity.
- Assets return 404: a proxy subpath was configured without rebuilding Bulwark.
- Cookies are rejected: verify HTTPS termination, forwarded headers, and SameSite requirements.

<!-- @AI-METADATA
type: chart-docs
title: Bulwark Mail exposure
description: Ingress, Gateway API, and JMAP CORS guidance
keywords: bulwark, ingress, gateway-api, cors
purpose: Expose Bulwark Mail correctly
scope: Chart
relations:
  - charts/bulwark-mail/README.md
path: charts/bulwark-mail/docs/exposure.md
version: 1.0
date: 2026-09-28
-->
