# Operations, recovery and troubleshooting

## Health and monitoring

Glance exposes GET /api/healthz. The endpoint stays public so kubelet probes can
check a private dashboard without carrying a user password. A successful probe
means the HTTP application initialized; it does not prove every external feed is
available. Verify important widgets separately and inspect application logs.
Use an existing blackbox exporter to monitor availability through the public TLS
endpoint. No native Prometheus metrics endpoint was identified in v0.8.6, so this
chart does not create a misleading ServiceMonitor.

## Upgrades

Review tagged upstream release notes before changing image.tag. Keep a copy of
the previous image tag and values. For image changes use Helm's normal merged
values or --reset-then-reuse-values; --reuse-values can preserve an old image tag.
Confirm the effective Deployment image after rollout. Avoid deleting a generated
authentication Secret during an upgrade because that invalidates retained sessions.

## Recovery inventory

Store the complete configuration/values in Git without secrets. Back up the
external secret source or encrypted Kubernetes Secret backups, and preserve any
public assets ConfigMap. Restore those resources before creating a replacement
release. Keep the same username and signing key to preserve unexpired sessions.
The chart has no database or filesystem content volume. Browser-local Todo data
requires browser profile recovery and is not covered by Kubernetes backups.

## Replica behavior

Two replicas can serve the same configuration with the same signing material.
Their widget caches and login rate-limit counters are independent. A PDB affects
voluntary disruptions only. Spread replicas over real nodes for node-level
resilience; a two-pod deployment on one node is not zone redundancy.

## Troubleshooting

| Symptom | Check | Action |
|---|---|---|
| Pending pod | Scheduling events and resource requests | Supply node capacity or adjust scheduling constraints |
| ImagePullBackOff | Registry reachability and pinned tag | Verify the upstream manifest and mirror credentials |
| Missing Secret volume | Referenced name, namespace and keys | Create or synchronize the expected Secret |
| ESO not Ready | SecretStore readiness and remote key | Correct provider permissions or key mapping |
| Invalid signing-key error | Decoded secret-key length | Use exactly 64 random bytes, base64 encoded |
| Login fails | Username, current password and limiter | Correct credentials and wait for the rate-limit window |
| Session lost after upgrade | Secret ownership and key changes | Restore original signing material or sign in again |
| Broken assets under subpath | Proxy rewrite and server.baseUrl | Strip the external prefix before forwarding |
| Dashboard unreachable through ingress | Policy peers, class, DNS and TLS | Admit the actual ingress controller and fix its route |
| Widget cannot reach an API | Egress destination, port and token | Add a narrowly scoped rule and synchronize credentials |
| Go template errors | Literal config and upstream widget syntax | Preserve Glance templates; do not apply Helm tpl |
| Updated Secret has no effect | Operator sync and pod age | Roll out pods or configure a reloader |
| Node drain blocks | PDB replicas and scheduling capacity | Restore a healthy second replica before draining |
| Missing Todo items on another device | Browser-local storage | Use the original browser profile; no server sync is promised |

## Validation boundary

The chart-owned runtime test checks native health, unauthorized access, a successful
login, rendered widget content, session reuse across replicas, credential retention
through Helm upgrade and pod replacement. It does not prove availability of all
third-party feeds, provider SSO, distributed rate limiting or browser data recovery.

<!-- @AI-METADATA
type: guide
title: Glance docs/operations
description: Product-specific Glance deployment and operation contract
keywords: glance, helm, authentication, widgets, kubernetes
purpose: Operate the Glance chart safely
scope: charts/glance
-->
