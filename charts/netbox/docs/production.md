# Production operations

## Availability

Scale web and worker workloads independently. Web replicas require shared RWX
media or a configured external media backend. Use an external highly available
PostgreSQL and Redis service when the availability target exceeds a single
node; enabling two web replicas does not make the bundled state stores HA.

With chart-managed ReadWriteOnce media, the worker uses a `Recreate` rollout
and required pod affinity to remain on the web pod's node. Declare
`ReadWriteMany` before applying custom affinity or distributing either
workload across nodes.

## Network policy

When `networkPolicy.enabled=true`, the default empty `ingressFrom` keeps the
HTTP listener reachable from IPv4 and IPv6 ingress controllers while egress
restrictions still apply. Set explicit Kubernetes NetworkPolicy peers in
`networkPolicy.ingressFrom` when the platform has stable controller or client
selectors.

## Backup and restore

Capture PostgreSQL and the media volume in the same recovery window. Test
restores into an isolated namespace. Redis cache can be rebuilt, but queued
jobs in Redis database 0 may affect recovery sequencing. Pause writers during
a strict point-in-time restore.

## Upgrade

The former `web.requestTimeout` value was removed because netbox-docker 5.0.2
never consumed `GRANIAN_REQUEST_TIMEOUT`, and Granian 2.7.9 has no equivalent
whole-request timeout option. Remove this key from overlays; enforce external
request deadlines at the ingress, Gateway, or load balancer.

Read the NetBox and netbox-docker release notes. Back up state, update the
combined image tag, deploy one environment, wait for migrations and probes,
then exercise login, API, worker, media upload, and metrics. Major NetBox
versions may require staged upgrades.

## Plugins

Build plugins into a derived immutable image. Pin their versions and test them
against the target NetBox release. Do not install packages from the Internet
in init containers.

<!-- @AI-METADATA
type: chart-docs
title: NetBox production operations
description: Availability, backup, restore, and upgrades
keywords: netbox, production, backup, upgrade
purpose: Operate NetBox safely
scope: Chart
path: charts/netbox/docs/production.md
version: 1.0
date: 2026-07-31
-->
