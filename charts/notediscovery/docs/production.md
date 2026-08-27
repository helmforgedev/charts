<!-- SPDX-License-Identifier: Apache-2.0 -->

# Production Guide

NoteDiscovery stores notes, images, drawings, search data, and writable plugin
state under `/app/data`. The supported production topology is one application
pod backed by one durable volume.

## Authentication And Browser Origins

Enable authentication for every shared deployment. Prefer
`auth.existingSecret` with a complete `config.yaml` so session secrets,
passwords, and API keys do not enter Helm release values. Restrict
`notediscovery.allowedOrigins` to the exact public HTTPS origins and keep debug
mode disabled.

## Storage And Backups

Back up the entire data volume, including its `plugins` directory. Verify a
restore into a clean namespace before upgrades. Use a StorageClass that
supports snapshots and expansion, and keep `persistence.mountPath` stable.

## Scaling Boundary

The generated volume is `ReadWriteOnce` and the Deployment uses `Recreate`.
Keep `replicaCount=1`. Supplying a shared existing claim removes the render-time
guard, but the operator must independently validate concurrent file writes,
search indexing, and plugin state before running multiple replicas.

## Network And MCP Access

Terminate TLS at Ingress or Gateway API and enable NetworkPolicy. The default
policy permits inbound HTTP from namespaces and adds DNS/HTTPS egress only when
custom egress rules are configured. Limit MCP and API access to trusted clients
and rotate exposed API keys.

<!-- @AI-METADATA
type: chart-docs
title: NoteDiscovery Production Guide
description: Production controls for NoteDiscovery authentication, storage, scaling, and MCP access
keywords: notediscovery, production, markdown, authentication, mcp
purpose: Document the supported production topology
scope: Chart
relations:
  - charts/notediscovery/values.yaml
path: charts/notediscovery/docs/production.md
version: 1.0
date: 2026-08-27
-->
