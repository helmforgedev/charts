# Networking and observability

NetBox listens on container port 8080 and is exposed through a Service named
after the release. Ingress and Gateway API are optional. Terminate TLS at the
chosen edge and restrict `netbox.allowedHosts` to the public hostname.

The network policy permits web ingress from configured peers, defaulting to
pods in the release namespace. Optional egress enforcement permits DNS and
selects only the bundled PostgreSQL and Redis pods. External databases,
external Redis, Sentry, remote data sources, webhooks, and object storage
require explicit `networkPolicy.egress.extraEgress` rules. Set
`isolatedDeployment=true` when outbound Internet access is intentionally
unavailable.

Native metrics are exposed at `/metrics` only when
`netbox.metricsEnabled=true`. A ServiceMonitor can discover the Service.
Monitor web readiness, worker replica availability, queue depth, database
health, job failures, and housekeeping completion.

<!-- @AI-METADATA
type: chart-docs
title: NetBox networking and observability
description: Routing, network policy, and metrics
keywords: netbox, networking, prometheus
purpose: Expose and monitor NetBox
scope: Chart
path: charts/netbox/docs/networking.md
version: 1.0
date: 2026-07-31
-->
