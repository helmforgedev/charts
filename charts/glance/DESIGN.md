# Glance chart design

## Product boundary

Glance is a Go dashboard that renders configured feeds, bookmarks and widgets.
The upstream image has no database server, worker process, application storage
volume or built-in Prometheus endpoint. This chart preserves that architecture.
Configuration and credential sources are the durable deployment state.
Browser-local Todo data is not stored in a Kubernetes PVC.

## Authentication contract

The chart enables native authentication and configures one dashboard account.
All users of that account share the same view; it is not a multi-tenant portal.
Generated passwords contain 32 random alphanumeric characters. Session keys
encode 64 random bytes, matching the tagged upstream implementation exactly.
Helm lookup reuses an existing Secret during upgrades. Inline values deliberately
override retained material, while existingSecret transfers ownership to the user
or External Secrets Operator. Offline helm template cannot look up the cluster;
GitOps systems that continuously render offline should use an existing Secret.

Neither password nor signing key appears in the ConfigMap. Glance resolves
projected files through its native secret interpolation. Configuration is rendered
with toYaml rather than tpl so custom-api widget Go templates remain literal.
The chart owns auth and server sections and rejects attempts to override them
through config.data. This keeps ports, health probes and credential mounts aligned.

## Restricted runtime

The default pod runs as UID/GID 10001 with a read-only root filesystem, dropped
capabilities, RuntimeDefault seccomp and no service account token. Configuration,
assets and Secret projections are read-only. No Docker socket or hostPath is
mounted. Docker-container widgets need a separately secured API integration;
the chart does not expose the host Docker daemon to satisfy a dashboard widget.

## Availability and scheduling

RollingUpdate uses zero unavailable pods and a one-pod surge. Two replicas can
share immutable configuration and signing material without a data volume.
Widget caches and login rate limits remain process-local. A shared cookie can
authenticate on either pod, but the chart does not claim distributed rate limiting.
Sensitive public deployments should enforce limits at a trusted ingress edge.
An optional PDB requires two or more replicas and cannot allow all replicas to be
unavailable. Topology spreading is explicit; node capacity remains the operator's
responsibility. A one-node lab proves process behavior, not zone failure recovery.

## Network and exposure

Default ingress admits only pods in the deployment namespace. DNS plus outbound
HTTP/HTTPS allows ordinary feeds. Operators can replace destination CIDRs or add
explicit egress for intranet APIs. The policy requires an enforcing CNI.
Trust of proxy headers is opt-in and must be coupled to restricted proxy access.
Ingress and Gateway resources refer to existing controllers. Gateway listeners
terminate TLS; subpath deployments require a prefix-stripping rule at the proxy.

## Observability and recovery

Native /api/healthz probes are independent of third-party feed availability.
The functional gate additionally checks auth, dashboard content, cross-pod cookies,
Secret retention during Helm upgrade and session reuse after pod replacement.
ExternalSecrets is exercised against a real operator and validated with CRD schema.
No artificial ServiceMonitor points at a nonexistent metrics endpoint.
Backups comprise values/configuration, static assets and the credential source.
There is no CronJob copying a nonexistent database, and no claim that server
backups recover browser-local storage.

## Upgrade and rotation

A configuration checksum rolls pods after Helm-managed config changes. Explicit
authentication values also participate in a checksum; generated random values do
not cause incidental rollouts. Updating a referenced Secret requires a controlled
rollout or an external reloader. Secret projection updates alone are not promised
to reload already parsed authentication configuration. Rotating the signing key
invalidates existing sessions; retaining it preserves sessions across restarts.

<!-- @AI-METADATA
type: guide
title: Glance DESIGN
description: Product-specific Glance deployment and operation contract
keywords: glance, helm, authentication, widgets, kubernetes
purpose: Operate the Glance chart safely
scope: charts/glance
-->
