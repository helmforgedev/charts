<!-- SPDX-License-Identifier: Apache-2.0 -->

# Production Guide

BookLore stores application state, book files, and imported files on separate
volumes and relies on MariaDB for relational data. A production backup must
cover the database plus every enabled BookLore volume.

## Scaling Boundary

Keep `replicaCount=1` with the default `ReadWriteOnce` volumes. Horizontal
scaling requires shared writable storage for `/app/data`, `/books`, and
`/bookdrop`, plus validation that concurrent workers do not process the same
BookDrop item. The chart does not claim that topology as supported.

## Credentials

Use `mariadb.auth.existingSecret` for the bundled database or
`database.external.existingSecret` for an external database. Do not store
production passwords in a values file. External Secrets can create either
Secret before BookLore starts.

## Network And Browser Origins

Set `app.allowedOrigins` to the public HTTPS origin instead of the permissive
default. Enable TLS on Ingress or Gateway API and use NetworkPolicy egress
rules that allow DNS, MariaDB, and any metadata providers BookLore must reach.

## Availability And Storage

The PodDisruptionBudget protects the single pod from voluntary eviction, but
it does not provide high availability. Use a StorageClass with snapshots and
expansion, test volume restoration, and schedule maintenance windows when the
pod must be restarted.

<!-- @AI-METADATA
type: chart-docs
title: BookLore Production Guide
description: Production operating boundaries for BookLore storage, credentials, and availability
keywords: booklore, production, mariadb, storage, backup
purpose: Document the supported production topology
scope: Chart
relations:
  - charts/booklore/values.yaml
path: charts/booklore/docs/production.md
version: 1.0
date: 2026-08-27
-->
