# BentoPDF design

## Runtime

Official static assets and security-header includes stay immutable. The chart starts NGINX directly as UID/GID 101 with
only temporary directories writable. The maintained nginx.conf derives from the pinned upstream release, preserving
routing and browser isolation. User configuration is serialized as JSON without evaluating Helm expressions.

## State and identity

There is no server document database, native authentication or durable volume. Adding a database or backup CronJob would
misrepresent the product. Authentication belongs to the edge. Tool visibility is a public presentation control.

## Scaling and monitoring

Replicas and HPA serve static assets. HPA tracks only the application container, excluding exporter CPU. PDB validation
uses HPA minimum replicas when applicable. Separate network peers control HTTP and metrics access. NGINX status is
loopback-only.

The official exporter exposes real NGINX counters. A Prometheus fixture verifies discovery and scrape. No invented PDF
operation metrics are provided. Pod egress defaults to deny, but browser CDN requests remain client-side.

## Upgrade and validation

ConfigMap subPath changes trigger checksum rollouts. RollingUpdate with maxUnavailable zero requires surge capacity.
There are no migration hooks or generated secrets. Browser caching and external assets remain upstream compatibility
considerations.

The runtime hook uses Chromium and deterministic PDFs to verify downloaded page count and dimensions, request methods,
headers, public configuration and rollout continuity. Monitoring profiles query real Prometheus. This does not certify
every PDF format or audit all upstream dependencies.

<!-- @AI-METADATA
 type: guide
 title: BentoPDF design
 description: Product-specific deployment decisions
 keywords: bentopdf, nginx, browser
 purpose: Explain implementation tradeoffs
 scope: chart
 path: charts/bentopdf/DESIGN.md
 version: 1.0
 date: 2026-09-10
-->
