# Matomo Chart Design

## Scope

This chart deploys the official Matomo Apache image, a web Service, optional
Ingress/Gateway API exposure, persistent application storage, a MySQL subchart
or external MySQL/MariaDB connection, and a CronJob for Matomo archiving.

## Differentiation

- Uses the official `docker.io/library/matomo` image instead of vendor images.
- Makes the production archiver CronJob first-class.
- Keeps external database and External Secrets flows explicit for managed DBs.
- Supports dual-stack Service fields, Gateway API, and NetworkPolicy defaults.

## Non-goals

- It does not embed Redis session management by default because Matomo session
  topology varies by installation.
- It does not manage Matomo plugins or marketplace lifecycle.
- It does not configure Matomo trusted proxy settings inside the database; the
  chart documents the reverse proxy requirement and exposes `extraEnv`.

## Validation Notes

The default profile is intentionally small enough for k3d validation while still
using persistent storage and the real Matomo image. Production users should move
database state to an external managed MySQL/MariaDB service and retain both DB
and application volume backups.

<!-- @AI-METADATA
type: chart-design
title: Matomo Chart Design
description: Design decisions for the Matomo HelmForge chart
keywords: matomo, design, architecture
purpose: Capture chart scope and trade-offs
scope: Chart
relations:
  - charts/matomo/values.yaml
path: charts/matomo/DESIGN.md
version: 1.0
date: 2026-07-06
-->
