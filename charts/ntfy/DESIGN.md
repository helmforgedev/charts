# ntfy Chart Design

## Scope

This chart deploys ntfy, a self-hosted HTTP pub-sub notification service.

Supported use cases:

- personal or team notification endpoints
- script-driven push notifications
- single-instance deployments backed by persistent SQLite or external PostgreSQL
- ingress or Gateway API exposure for public HTTPS access
- optional Prometheus scraping through the ntfy metrics endpoint

## Architecture

```mermaid
flowchart LR
  user[User or script] --> route[Ingress or HTTPRoute]
  route --> svc[Service]
  svc --> pod[ntfy pod]
  pod --> cfg[ConfigMap server.yml]
  pod -. optional persistence .-> pvc[(PVC or emptyDir /var/cache/ntfy)]
  pod -. optional database URL Secret .-> secret[Secret]
  pod -. optional external database .-> postgres[(PostgreSQL)]
  pod -. optional ban feed .-> pvc
  pvc -. external consumer .-> ban[fail2ban or equivalent]
  prom[Prometheus] -. optional .-> svc
```

## Design Choices

- Use the upstream `binwiederhier/ntfy` image.
- Keep the workload single-replica because ntfy stores cache and auth data in local SQLite files.
- Allow PostgreSQL to replace all SQLite stores without placing its connection URL in the ConfigMap.
- Consume the PostgreSQL URL from a Kubernetes Secret and optionally reconcile it with External Secrets Operator.
- Keep persistence enabled by default so message cache, attachments, and auth data survive restarts.
- Render Gateway API HTTPRoutes as an opt-in exposure path alongside Ingress.
- Keep Service dual-stack fields opt-in so clusters without dual-stack support use their defaults.
- Keep authentication user lifecycle out of the chart; ntfy users are managed with the upstream CLI.
- Keep the 2.26.3 abuse ban-feed opt-in, persist its default file on the existing data volume, and leave firewall enforcement to an external consumer.

## Production Boundary

Recommended production controls:

- set `ntfy.baseUrl` to the public HTTPS URL clients will use
- enable authentication and set `ntfy.authDefaultAccess: deny-all` for private deployments
- keep persistence enabled with a durable storage class
- use a provider-managed Secret for PostgreSQL credentials
- back up the PVC before upgrades
- expose the service only through trusted ingress or Gateway policy
- set explicit resources for shared clusters
- rotate the ban-feed with copy-truncate semantics when it is enabled

## Non-Goals

- multi-replica SQLite coordination
- automatic multi-replica or shared-attachment configuration for PostgreSQL deployments
- user account reconciliation
- installing Gateway API CRDs or controllers
- installing Prometheus Operator CRDs
- installing fail2ban or changing node firewall rules

## Validation

The chart is expected to pass:

- Helm lint and strict lint
- Helm template rendering for default and CI values
- helm-unittest coverage for deployment, service, persistence, ingress, Gateway API, and metrics
- kubeconform validation for Kubernetes-native default manifests
- local k3d deployment smoke tests with pod logs and namespace events checked
- an opt-in k3d scenario that renders and starts with the upstream ban-feed settings

<!-- @AI-METADATA
type: design
title: ntfy Chart Design
description: Design document for the ntfy Helm chart covering single-instance SQLite storage, exposure paths, metrics, and validation.
keywords: ntfy, notifications, helm, sqlite, gateway-api, prometheus
purpose: Document chart architecture, boundaries, and operational decisions.
scope: Chart Design
relations:
  - charts/ntfy/README.md
  - charts/ntfy/docs/configuration.md
path: charts/ntfy/DESIGN.md
version: 1.0
date: 2026-06-10
-->
